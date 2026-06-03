import azure.functions as func

from functionapp.proxy import blueprint as proxy

app = func.FunctionApp()
app.register_blueprint(proxy)
