import azure.functions as func
from import_on_upload import blueprint as upload_blueprint
from import_on_timer import blueprint as timer_blueprint

app = func.App()
app.register_functions(upload_blueprint)
app.register_functions(timer_blueprint)
