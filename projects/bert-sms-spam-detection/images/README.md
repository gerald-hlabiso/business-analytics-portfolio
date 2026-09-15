## Project Visuals

### Model Comparison

The comparison demonstrates that the traditional baseline remained highly competitive, while BERT provided strong contextual and probability-ranking performance.

![Logistic Regression and BERT model comparison](./images/model-comparison.png)

### Precision–Recall Performance

BERT achieved an Average Precision score of **99.00%**, demonstrating strong spam-ranking performance despite the class imbalance.

![BERT precision-recall curve](./images/precision-recall-curve.png)

### Test-Set Error Analysis

The confusion matrix shows **548 correct predictions**, **5 false positives**, and **5 false negatives** across 558 held-out messages.

![BERT test confusion matrix](./images/error-analysis.png)

### Realistic SMS Predictions

The trained model assigns high spam probabilities to promotional and phishing messages while preserving low probabilities for ordinary communication.

![BERT realistic SMS prediction demonstration](./images/sms-prediction-demo.png)
