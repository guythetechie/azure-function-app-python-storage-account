import azure.functions as func
from functionapp.import_with_service_bus import blueprint as service_bus_blueprint
from import_on_timer import blueprint as timer_blueprint

app = func.App()
app.register_functions(service_bus_blueprint)
app.register_functions(timer_blueprint)
