# train_rain_model.py
import dagshub
import mlflow
import mlflow.sklearn
from utils import split_data
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score
import pandas as pd

dagshub.init(repo_owner='IbrahimFaye', repo_name='weather-agri', mlflow=True)

def main():
    mlflow.set_experiment("rain_forecast")
    df = pd.read_csv("../data/features.csv").dropna(subset=["rain_label"])
    X = df[["temp_c", "humidity", "pressure", "wind_speed", "hour", "month"]]
    y = df["rain_label"]
    X_train, X_test, y_train, y_test = split_data(df, "rain_label")

    with mlflow.start_run():
        model = RandomForestClassifier(n_estimators=150, random_state=42)
        model.fit(X_train, y_train)
        preds = model.predict(X_test)
        acc = accuracy_score(y_test, preds)
        f1 = f1_score(y_test, preds)

        mlflow.log_params({"n_estimators": 150, "random_state": 42})
        mlflow.log_metrics({"accuracy": acc, "f1_score": f1})
        mlflow.sklearn.log_model(model, "rain_model")

        print(f"✅ Rain Model — Accuracy: {acc:.3f} | F1: {f1:.3f}")
        print("🔗 Tes résultats sont visibles sur DagsHub !")

if __name__ == "__main__":
    main()
