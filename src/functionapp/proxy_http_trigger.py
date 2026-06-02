import logging
from dataclasses import dataclass
from urllib.parse import urlparse

import azure.functions as func
import httpx

blueprint = func.Blueprint()

TARGET_URL_HEADER = 'target_url'


class ProxyRequestError(Exception):
    status_code = 400


class BadRequestError(ProxyRequestError):
    status_code = 400


class UpstreamError(ProxyRequestError):
    status_code = 502


class UpstreamTimeoutError(ProxyRequestError):
    status_code = 504


@dataclass(frozen=True)
class ProxyRequest:
    method: str
    target_url: str
    headers: dict[str, str]
    body: bytes


def parse_method(request: func.HttpRequest) -> str:
    method = request.method.upper()
    if method not in {'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'}:
        raise BadRequestError(f'Unsupported method: {method}.')

    logging.info('Parsed method: %s', method)
    return method


def parse_target_url(request: func.HttpRequest) -> str:
    target_url = request.headers.get(TARGET_URL_HEADER)
    if not target_url:
        raise BadRequestError(f'Missing required {TARGET_URL_HEADER} header.')

    parsed_url = urlparse(target_url)
    if not parsed_url.hostname:
        raise BadRequestError('Target URL must include a host name.')

    logging.info('Parsed target URL header for host: %s', parsed_url.hostname)
    return target_url


def parse_body(request: func.HttpRequest) -> bytes:
    return request.get_body() or b''


def parse_headers(request: func.HttpRequest) -> dict[str, str]:
    headers = dict(request.headers.items())

    logging.info('Parsed %d forwarded request headers.', len(headers))
    return headers


def parse_proxy_request(request: func.HttpRequest) -> ProxyRequest:
    return ProxyRequest(
        method=parse_method(request),
        target_url=parse_target_url(request),
        headers=parse_headers(request),
        body=parse_body(request),
    )


async def send_proxy_request(proxy_request: ProxyRequest) -> httpx.Response:
    timeout = httpx.Timeout(10.0, connect=5.0)
    async with httpx.AsyncClient(follow_redirects=False, timeout=timeout) as client:
        try:
            return await client.request(
                method=proxy_request.method,
                url=proxy_request.target_url,
                headers=proxy_request.headers,
                content=proxy_request.body,
            )
        except httpx.TimeoutException as error:
            raise UpstreamTimeoutError(
                'The upstream service timed out.') from error
        except httpx.RequestError as error:
            raise UpstreamError(
                'The upstream service could not be reached.') from error


def build_proxy_response(response: httpx.Response) -> func.HttpResponse:
    return func.HttpResponse(
        body=response.content,
        status_code=response.status_code,
        headers=dict(response.headers.items()),
    )


def build_error_response(error: ProxyRequestError) -> func.HttpResponse:
    logging.warning('Proxy request failed: %s', error)
    return func.HttpResponse(str(error), status_code=error.status_code)


@blueprint.function_name(name='proxy')
@blueprint.route(route='proxy', auth_level=func.AuthLevel.FUNCTION)
async def proxy(req: func.HttpRequest) -> func.HttpResponse:
    try:
        proxy_request = parse_proxy_request(req)
        logging.info('Proxying %s request.', proxy_request.method)
        upstream_response = await send_proxy_request(proxy_request)
        return build_proxy_response(upstream_response)
    except ProxyRequestError as error:
        return build_error_response(error)
    except Exception:
        logging.exception('Unexpected proxy failure.')
        return func.HttpResponse('Unexpected proxy failure.', status_code=500)
