
## Directory structure
    
    ├ data
    │   └ ru-en
    │      └ test
    │        ├ original
    │        │   ├ corpus
    │        │   │   ├ mtdata_JW300.en.gz
    │        │   │   └ mtdata_JW300.ru.gz
    │        │   ├ devset
    │        │   │   ├ flores_dev.en.gz
    │        │   │   └ flores_dev.ru.gz
    │        │   ├ eval
    │        │   │   ├ sacrebleu_wmt20.en.gz
    │        │   │   └ sacrebleu_wmt20.ru.gz
    │        │   ├ mono
    │        │   │   ├ news-crawl_news.2020.ru.gz
    │        │   │   └ news-crawl_news.2020.en.gz
    │        │   ├ devset.ru.gz
    │        │   └ devset.en.gz
    │        ├ clean
    │        │   ├ corpus
    │        │   │   ├ mtdata_JW300.en.gz
    │        │   │   └ mtdata_JW300.ru.gz
    │        │   ├ mono
    │        │   │   ├ news-crawl_news.2020.ru.gz
    │        │   │   └ news-crawl_news.2020.en.gz
    │        │   ├ mono.ru.gz
    │        │   └ mono.en.gz
    │        ├ biclean
    │        │   ├ corpus
    │        │   │   ├ mtdata_JW300.en.gz
    │        │   │   └ mtdata_JW300.ru.gz
    │        │   ├ corpus.ru.gz
    │        │   ├ corpus.en.gz
    │        ├ translated
    │        │   ├ mono.ru.gz
    │        │   └ mono.en.gz
    │        ├ augmented
    │        │   ├ corpus.ru.gz
    │        │   └ corpus.en.gz
    │        ├ alignment
    │        │   ├ corpus.aln.gz
    │        │   └ lex.s2t.pruned.gz
    │        ├ merged
    │        │   ├ corpus.ru.gz
    │        │   └ corpus.en.gz
    │        └ filtered
    │            ├ corpus.ru.gz
    │            └ corpus.en.gz
    ├ models
    │   └ ru-en
    │       └ test
    │          ├ backward
    │          ├ teacher-base0
    │          ├ teacher-base1
    │          ├ teacher-finetuned0
    │          ├ teacher-finetuned1
    │          ├ student
    │          ├ student-finetuned
    │          ├ speed
    │          ├ evaluation
    │          │  ├ backward
    │          │  ├ teacher-base0
    │          │  ├ teacher-base1
    │          │  ├ teacher-finetuned0
    │          │  ├ teacher-finetuned1
    │          │  ├ teacher-ensemble
    │          │  ├ student
    │          │  ├ student-finetuned
    │          │  └ speed
    │          └ exported
    │
    ├ experiments
    │   └ ru-en
    │      └ test
    │         └ config.sh
    ├ logs
    │   └ ru-en
    │      └ test
    │         └ clean_corpus.log
