# BERT SMS Spam Detection — Project Images

High-resolution model evaluation and demonstration visuals for the BERT SMS Spam Detection project.

## Model Comparison

The comparison demonstrates that the traditional baseline remained highly competitive, while BERT provided strong contextual and probability-ranking performance.

![Logistic Regression and BERT model comparison](./model-comparison.png)

## Precision–Recall Performance

BERT achieved an Average Precision score of **99.00%**, demonstrating strong spam-ranking performance despite the class imbalance.

![BERT precision-recall curve](./precision-recall-curve.png)

## Test-Set Error Analysis

The confusion matrix shows **548 correct predictions**, **5 false positives**, and **5 false negatives** across 558 held-out messages.

![BERT test confusion matrix](./error-analysis.png)

## Realistic SMS Predictions

The trained model assigns high spam probabilities to promotional and phishing messages while preserving low probabilities for ordinary communication.

![BERT realistic SMS prediction demonstration](./sms-prediction-demo.png)
