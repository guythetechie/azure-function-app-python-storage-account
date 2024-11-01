import azure.functions as func
from import_on_timer import blueprint as timer_blueprint
from import_with_storage_queue import blueprint as storage_queue_blueprint

app = func.FunctionApp()

app.register_blueprint(timer_blueprint)
app.register_blueprint(storage_queue_blueprint)
