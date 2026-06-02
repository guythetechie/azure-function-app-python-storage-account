import azure.functions as func
import logging

app = func.FunctionApp()


@app.function_name(name="proxy")
@app.route(route="hello", auth_level=func.AuthLevel.ANONYMOUS)
async def test_function(request: func.HttpRequest) -> func.HttpResponse:
    method = request.method
    logging.info(f'Python HTTP trigger function processed a {method} request.')
    return func.HttpResponse(
        "This HTTP triggered function executed successfully.",
        status_code=200
    )
