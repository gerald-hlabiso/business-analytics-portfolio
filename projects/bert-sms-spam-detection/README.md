# BERT SMS Spam Detection

An end-to-end natural language processing project that fine-tunes BERT to classify SMS messages as legitimate (**ham**) or **spam**, compares it with a traditional machine-learning baseline, and evaluates the operational tradeoff between missed spam and blocked legitimate messages.

## Business Question

**Can a fine-tuned BERT model improve SMS spam detection while maintaining an acceptable balance between missed spam messages and incorrectly blocked legitimate messages?**

Spam filtering is a risk-sensitive classification problem. False negatives may expose users to phishing, fraud, and unwanted content, while false positives can block legitimate communication. Therefore, this project evaluates precision, recall, F1 score, probability ranking, threshold stability, and message-level errors rather than relying on accuracy alone.

## Project Highlights

* Fine-tuned `google-bert/bert-base-uncased` using the Hugging Face `Trainer` API
* Benchmarked BERT against TF-IDF with Logistic Regression
* Used a stratified 80/10/10 training, validation, and testing split
* Applied class-weighted cross-entropy loss to address class imbalance
* Selected the decision threshold using validation data instead of the test set
* Evaluated false positives and false negatives at the message level
* Tested the model using realistic promotional, phishing, and legitimate messages

## Dataset

The project uses the [UCI SMS Spam Collection](https://archive.ics.uci.edu/dataset/228/sms+spam+collection), accessed through the Hugging Face `ucirvine/sms_spam` dataset.

| Split      |  Messages |       Ham |    Spam |
| ---------- | --------: | --------: | ------: |
| Training   |     4,459 |     3,861 |     598 |
| Validation |       557 |       483 |      74 |
| Test       |       558 |       483 |      75 |
| **Total**  | **5,574** | **4,827** | **747** |

Spam represents approximately **13.4%** of the dataset, making class-sensitive eval

