import azure.functions as func

from proxy_http_trigger import blueprint as proxy_blueprint

app = func.FunctionApp()
app.register_blueprint(proxy_blueprint)
