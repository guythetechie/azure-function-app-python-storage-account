import azure.functions as func

from proxy_http_trigger import blueprint as http_trigger_blueprint

app = func.FunctionApp()

app.register_blueprint(http_trigger_blueprint)
