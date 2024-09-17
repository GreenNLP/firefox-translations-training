# Pipeline steps

Below is an overview of the pipeline steps:

![Alt text](pipeline.png)

The pipeline consists of five main steps:
* **Data Preprocessing**: Downloads data from publicly available repositories and handles basic data cleaning.
* **Synthetic Dataset Generation**: Downloads the relevant teacher and backward models, forward translates all source sentences with our teacher model(s) into the target languages, computes cross-entropy scores with a backward model, and then filters the synthetic dataset.
* **Student Training**: Trains a small transformer model on the filtered synthetic dataset with guided alignment.
* **Exporting**: Creates the final student. It includes a fine-tuning step, a quantization step and, finally, the export step which saves the model so it is ready for deployment.
* **Evaluation**: Evaluates the trained model.

The steps are based on [train-student](https://github.com/browsermt/students/tree/master/train-student) recipe.

They can be represented as a Directly Acyclic Graph (DAG).

Step | Description | Bottleneck | Comments
--- | --- | --- | ---
Installation | Installing dependencies and compiling | CPU | Takes ~1 hour
Data downloading | Downloads datasets, samples sentences | Network, Disk | Time depends on dataset size, sampling of huge mono datasets (100M+ sentences) is the most intensive operation.
Data cleaning | Basic preprocessing, dataset specific, language specific, rule based and other attempts to clean noisy data in parallel and mono datasets | CPU | Good parallelization across CPU cores. To make cleaning of a new language more efficient add it to [clean_parallel.py](/pipeline/clean/tools/clean_parallel.py).
Merge and dedupe | Merges clean dataset and applies deduplicaiton | CPU, Disk | 
Training vocabulary | Trains [SentencePiece](https://github.com/google/sentencepiece) vocabulary/tokenizer model on parallel corpus. | CPU |
Teacher download | Downloads teacher model | CPU |
Backward model download | Downloads backward model | CPU |
Translation by teacher | Translates a corpus using the teacher models | GPU | The slowest part of the pipeline. Can take days. It is possible to speed it up by using multiple nodes in cluster mode.
Cross-entropy filtering | Scores translated corpus with backward s2s model and removes a part of the corpus with the lowest scores to reduce noise | GPU, CPU, Disk | At this point we work with huge datasets. Very disk intensive.
Training alignments and shortlist | Trains alignments using [fast_align](https://github.com/clab/fast_align) and extracts lexical shortlist using [extract_lex](https://github.com/marian-nmt/extract-lex) tool | CPU, Disk | Some tools require uncompressed datasets on disk and they are huge at this point. Good CPU parallelization.
Training student | Trains a small transformer student model on filtered data and using alignments. Shuffling in RAM might fail if dataset is huge and there's not enough RAM on the machine, so it's recommended to remove it and use `shuffle: batches` marian settings (see [issue](https://github.com/mozilla/firefox-translations-training/issues/21)).  | GPU |
Fine-tuning student | Finetunes the student model by emulating 8bit GEMM during training | GPU | Converges very quickly and then degrades. It's quick but you might want to reduce early stopping threshold.
Quantizaiton |  Applies 8 bit quantization to the fined-tuned student model and runs evaluation on CPU | CPU | CPU threads must be set to 1 for this step.
Evaluation |  Calculates metrics for all models (BLEU, chrf) using [SacreBLEU](https://github.com/mjpost/sacrebleu) | GPU | Uses `datasets.test` configuration section.
Export | Exports trained model and shortlist to (bergamot-translator)(https://github.com/mozilla/bergamot-translator) format | |

## Configurable steps

Summary of OpusDistillery main steps. For each step, we report the compute resource used (CPU or GPU), whether the step is optional, and whether it is configurable or hard-coded.

| **Main Step**                 | **Step**                   | **Resource** | **Optional** | **Configurable** |
| ----------------------------- | -------------------------- | ------------ | ------------ | ---------------- |
| **Data Processing**            |                            |              |              |                  |
|                                | Data Download              | CPU          | ✗            | ✓                |
|                                | Data Cleaning              | CPU          | ✗            | ✓                |
| **Synthetic Dataset Generation**|                            |              |              |                  |
|                                | Teacher Model Download     | CPU          | ✗            | ✓                |
|                                | Forward Translation        | GPU          | ✗            | ✗                |
|                                | Backward Model Download    | CPU          | ✓            | ✓                |
|                                | Cross-Entropy Scoring      | GPU          | ✓            | ✗                |
|                                | Cross-Entropy Filtering    | CPU          | ✓            | ✓                |
| **Student Training**           |                            |              |              |                  |
|                                | Alignment Training         | CPU          | ✓            | ✗                |
|                                | Vocabulary Training        | CPU          | ✗            | ✓                |
|                                | Student Training           | GPU          | ✗            | ✓                |
| **Exporting**                  |                            |              |              |                  |
|                                | Fine-tuning                | GPU          | ✓            | ✓                |
|                                | Quantization               | CPU          | ✓            | ✗                |
|                                | Export                     | -            | ✓            | ✗                |
| **Evaluation**                 | Evaluation                 | GPU          | ✓            | ✗                |