import dagshub
dagshub.init(repo_owner='IbrahimFaye', repo_name='weather-agri', mlflow=True)

import mlflow
with mlflow.start_run():
  

  mlflow.log_metric('accuracy', 42)
  mlflow.log_param('Param name', 'Value')