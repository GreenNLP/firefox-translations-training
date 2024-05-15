OpusDistillery
==========

Welcome to OpusDistillery's documentation!

OpusDistillery is an end-to-end pipeline to perform systematic multilingual distillation of MT models.
It is built on top of the [Firefox Translations Training pipeline](https://github.com/mozilla/firefox-translations-training),
originally developed within the [Bergamot project](https://browser.mt), for training efficient NMT models that can run locally in a web browser.

New features:

* **OPUS-MT models**: We have added the option to simply provide the URL of an existing OPUS-MT model. Our tool is also able to select the best available OpusMT model per language pair.
* **GPU Utilisation** With the hope of moving towards greener NLP and NMT, we have added GPU utilisation tracking so that we can report the amount of hours and energy consumed by the pipeline.
* **Multilinguality Support**: The pipeline supports training multilingual models. This covers two aspects: support for using any combination of multilingual and bilingual teachers, as well as support for multilingual student training.

<!-- OpusDistillery has been presented in `ACL 2020 system demonstrations <https://www.aclweb.org/anthology/2020.acl-demos.20>`_.-->

.. toctree::
   :caption: Get started
   :maxdepth: 1

   installation.md
   usage.md
   automatic_configuration.md
   command_line_tools.md

.. toctree::
   :caption: Available functions
   :name: functions
   :maxdepth: 1

   functions/downloading_and_selecting_data.md
   functions/preprocessing_text.md
   functions/filtering_and_scoring.md
   functions/using_score_files.md
   functions/training_language_and_alignment_models.md
   functions/training_and_using_classifiers.md

.. toctree::
   :caption: Available filters
   :name: filters
   :maxdepth: 1
   :glob:

   filters/length_filters.md
   filters/script_and_language_identification_filters.md
   filters/special_character_and_similarity_filters.md
   filters/language_model_filters.md
   filters/alignment_model_filters.md
   filters/sentence_embedding_filters.md
   filters/custom_filters.md

.. toctree::
   :caption: Available preprocessors
   :name: preprocessors
   :maxdepth: 1

   preprocessors/tokenizer.md
   preprocessors/detokenizer.md
   preprocessors/whitespaceNormalizer.md
   preprocessors/reg_exp_sub.md
   preprocessors/monolingual_sentence_splitter.md
   preprocessors/bpe_segmentation.md
   preprocessors/morfessor_segmentation.md
   preprocessors/custom_preprocessors.md

.. toctree::
   :caption: Other information
   :maxdepth: 1
   
   references.rst
   CONTRIBUTING.md
   CHANGELOG.md
