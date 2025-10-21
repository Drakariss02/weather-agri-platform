# ml/utils.py
import os
import mlflow
from sklearn.model_selection import train_test_split

def setup_mlflow(experiment_name):
    mlflow.set_tracking_uri("file:./mlruns")
    mlflow.set_experiment(experiment_name)

def split_data(df, target_col):
    X = df.drop(columns=[target_col])
    y = df[target_col]
    return train_test_split(X, y, test_size=0.2, random_state=42)
