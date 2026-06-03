import azure.functions as func

from proxy import blueprint as proxy

app = func.FunctionApp()
app.register_blueprint(proxy)
