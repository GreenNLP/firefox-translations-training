# Directory structure

This is an example directory structure to train a student for English to Finnish and Estonian with a single teacher.

    
    ├ data
    │   └ dirname
    │      └ name
    │        ├ original
    │        │   ├ en-et
    |        |   │   ├ corpus
    |        |   │   │   ├ tc_Tatoeba-Challenge-v2023-09-26.source.gz
    |        |   │   │   └  tc_Tatoeba-Challenge-v2023-09-26.target.gz
    |        |   │   ├ devset
    |        |   │   │   ├ flores_dev.source.gz
    |        |   │   │   └ flores_dev.target.gz
    |        |   │   ├ eval
    |        |   │   │   ├ sacrebleu_wmt20.source.gz
    |        |   │   │   └ sacrebleu_wmt20.target.gz
    |        |   │   ├ devset.source.gz
    |        |   │   ├ devset.source.langtagged.gz
    |        |   │   ├ devset.student.source.langtagged.gz
    |        |   │   └ devset.target.gz
    │        │   ├ en-fi
    |        |   │   ├ corpus
    |        |   │   │   ├ tc_Tatoeba-Challenge-v2023-09-26.source.gz
    |        |   │   │   └  tc_Tatoeba-Challenge-v2023-09-26.target.gz
    |        |   │   ├ devset
    |        |   │   │   ├ flores_dev.source.gz
    |        |   │   │   └ flores_dev.target.gz
    |        |   │   ├ eval
    |        |   │   │   ├ sacrebleu_wmt20.source.gz
    |        |   │   │   └ sacrebleu_wmt20.target.gz
    |        |   │   ├ devset.source.gz
    |        |   │   ├ devset.source.langtagged.gz
    |        |   │   ├ devset.student.source.langtagged.gz
    |        |   │   └ devset.target.gz
    |        |   ├ devset.source.gz
    |        |   ├ devset.source.langtagged.gz
    |        |   ├ devset.student.source.langtagged.gz
    |        |   └ devset.target.gz
    │        ├ clean
    │        │   ├ en-et
    |        |   │   ├ corpus
    |        |   │   │   ├ tc_Tatoeba-Challenge-v2023-09-26.source.gz
    |        |   │   │   └ tc_Tatoeba-Challenge-v2023-09-26.target.gz
    |        |   │   ├ corpus.source.gz
    |        |   │   ├ corpus.source.langtagged.gz
    |        |   │   └ corpus.target.gz
    │        │   ├ en-fi
    |        |   │   ├ corpus
    |        |   │   │   ├ tc_Tatoeba-Challenge-v2023-09-26.source.gz
    |        |   │   │   └ tc_Tatoeba-Challenge-v2023-09-26.target.gz
    |        |   │   ├ corpus.source.gz
    |        |   │   ├ corpus.source.langtagged.gz
    |        |   │   └ corpus.target.gz
    |        |   ├ corpus.source.gz
    |        |   └ corpus.target.gz
    │        ├ merged
    │        │   ├ en-et
    |        |   │   ├ corpus.source.gz
    |        |   │   ├ corpus.source.opusmt.gz
    |        |   │   ├ corpus.target.opusmt.gz
    |        |   │   └ corpus.target.gz
    │        │   └ en-fi
    |        |       ├ corpus.source.gz
    |        |       ├ corpus.source.opusmt.gz
    |        |       ├ corpus.target.opusmt.gz
    |        |       └ corpus.target.gz
    │        ├ translated
    │        │   ├ en-et
    |        |   │   ├ corpus
    |        |   │   │   ├ file.00
    |        |   │   │   ├ file.00.0.opusmt
    |        |   │   │   ├ file.00.0.opusmt.log
    |        |   │   │   ├ file.00.0.opusmt.nbest   
    |        |   │   │   ├ file.00.nbest.0.out
    |        |   │   │   └ file.00.ref
    |        |   │   └ corpus.0.target.gz
    │        │   ├ en-fi
    |        |   │   ├ corpus
    |        |   │   │   ├ file.00
    |        |   │   │   ├ file.00.0.opusmt
    |        |   │   │   ├ file.00.0.opusmt.log
    |        |   │   │   ├ file.00.0.opusmt.nbest   
    |        |   │   │   ├ file.00.nbest.0.out
    |        |   │   │   └ file.00.ref
    |        |   │   └ corpus.0.target.gz
    │        ├ filtered
    │        │   ├ en-et
    |        |   │   ├ corpus.source.gz
    |        |   │   ├ corpus.source.langtagged.gz
    |        |   │   └ corpus.target.gz
    │        │   ├ en-fi
    |        |   │   ├ corpus.source.gz
    |        |   │   ├ corpus.source.langtagged.gz
    |        |   │   └ corpus.target.gz
    |        |   └ corpus.target.gz
    │        └ alignment
    │            ├ corpus.aln.gz
    │            └ lex.s2t.pruned.gz
    ├ models
    │   └ dirname
    │      └ name
    │          ├ en-et
    │          │   ├ backward
    │          │   └ teacher-base0-0
    │          ├ en-fi
    │          │   ├ backward
    │          │   └ teacher-base0-0
    │          ├ student
    │          ├ student-finetuned
    │          ├ speed
    │          ├ evaluation
    │          │  ├ teacher-ensemble
    │          │  ├ student
    │          │  ├ student-finetuned
    │          │  └ speed
    │          └ exported
    ├ experiments
    │   └ dirname
    │      └ name
    │         └ config.yml
    └ logs
        └ dirname
           └ name
              └ clean_corpus.log
