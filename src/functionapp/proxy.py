import logging
from dataclasses import dataclass
from http import HTTPMethod, HTTPStatus
from typing import AsyncIterator, Mapping, NamedTuple

import azure.functions as func
import azurefunctions.extensions.http.fastapi as fastapi
import httpx

blueprint = func.Blueprint()


class ParsedRequest(NamedTuple):
    """Parsed incoming proxy request."""

    method: HTTPMethod
    target_url: httpx.URL
    headers: Mapping[str, str]
    body: AsyncIterator[bytes]


@dataclass
class HttpError(Exception):
    """HTTP response details for expected proxy failures."""

    status_code: HTTPStatus
    detail: str

    def __post_init__(self) -> None:
        super().__init__(self.detail)


def parse_method(request: fastapi.Request) -> HTTPMethod:
    try:
        method = HTTPMethod(request.method)
        logging.info('Parsed method: %s', method)
        return method
    except ValueError as error:
        raise HttpError(
            status_code=HTTPStatus.BAD_REQUEST,
            detail=f'Invalid method: {request.method}.',
        ) from error


def parse_target_url(request: fastapi.Request) -> httpx.URL:
    HEADER_NAME = 'target_url'

    match request.headers.get(HEADER_NAME):
        case str(header_value):
            try:
                url = httpx.URL(header_value)
            except httpx.InvalidURL as error:
                raise HttpError(
                    status_code=HTTPStatus.BAD_REQUEST,
                    detail="Target URL is invalid.",
                ) from error

            if url.scheme not in {"http", "https"}:
                raise HttpError(
                    status_code=HTTPStatus.BAD_REQUEST,
                    detail=f"Target URL scheme {url.scheme} must be http or https.",
                )

            if not url.host:
                raise HttpError(
                    status_code=HTTPStatus.BAD_REQUEST,
                    detail="Target URL must include a host name.",
                )

            return url
        case _:
            raise HttpError(
                status_code=HTTPStatus.BAD_REQUEST,
                detail=f'Missing required {HEADER_NAME} header.',
            )


def parse_headers(request: fastapi.Request) -> Mapping[str, str]:
    headers = dict(request.headers.items())

    logging.info('Parsed %d forwarded request headers.', len(headers))
    return headers


def parse_request(request: fastapi.Request) -> ParsedRequest:
    return ParsedRequest(
        method=parse_method(request),
        target_url=parse_target_url(request),
        headers=parse_headers(request),
        body=request.stream(),
    )


async def send_parsed_request(parsed_request: ParsedRequest) -> fastapi.Response:
    timeout = httpx.Timeout(connect=10.0, read=60.0, write=60.0, pool=60.0)
    client = httpx.AsyncClient(follow_redirects=False, timeout=timeout)

    try:

        client_request = client.build_request(
            method=parsed_request.method.value,
            url=parsed_request.target_url,
            headers=parsed_request.headers,
            content=parsed_request.body
        )

        response = await client.send(client_request, stream=True)

        async def get_response_body() -> AsyncIterator[bytes]:
            try:
                async for chunk in response.aiter_bytes():
                    yield chunk
            finally:
                await response.aclose()
                await client.aclose()

        return fastapi.StreamingResponse(
            get_response_body(),
            status_code=response.status_code,
            headers=dict(response.headers.items()),
        )

    except httpx.HTTPError as error:
        await client.aclose()
        raise HttpError(
            status_code=HTTPStatus.BAD_GATEWAY,
            detail=f"Sending request failed with error: {error}",
        ) from error


@blueprint.function_name(name='proxy')
@blueprint.route(route='proxy', auth_level=func.AuthLevel.FUNCTION)
async def proxy(req: fastapi.Request) -> fastapi.Response:
    try:
        parsed_request = parse_request(req)
        response = await send_parsed_request(parsed_request)
        return response
    except HttpError as error:
        logging.warning('Returning HTTP error: %s', error)
        return fastapi.Response(str(error), status_code=error.status_code)
    except Exception as error:
        logging.exception('Unexpected proxy failure: %s', error)
        return fastapi.Response('Unexpected proxy failure.', status_code=500)
