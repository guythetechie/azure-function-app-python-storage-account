import azure.functions as func
from import_with_storage_queue import blueprint as storage_queue_blueprint
from import_on_timer import blueprint as timer_blueprint

app = func.App()
app.register_functions(storage_queue_blueprint)
app.register_functions(timer_blueprint)
