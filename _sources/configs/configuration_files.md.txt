# Configuration files

Configuration files are in [YAML](https://yaml.org/) format.
At the top level, they have two sections:

* `experiment`: contains all the relevant information for your experiment, except the information on which datasets to use.
* `datasets`: contains the infromation regarding the datasets used for training, development and evaluation. Datasets are explained in [Dataset importers](downloading_and_selecting_data.md).

At the beginning of your `experiment` section, you should define the following:

* `dirname`: directory name where everything will be stored.
* `name`: name of the experiment you are running. All generated data and models will be stored in `dirname`/`name`
* `langpairs`: a list of the language pairs you want in your student model, with **two letter codes**

```yaml

experiment:
  dirname: test
  name: fiu-eng
  langpairs:
    - et-en
    - fi-en
    - hu-en
```

## Data processing

### OpusFilter

We have added support for using [OpusFilter](https://github.com/Helsinki-NLP/OpusFilter), a tool for filtering and combining parallel corpora. For data filtering, instead of the default cleaning, you can choose to use opusfilter with a default configuration or with a specific configuration you provide.

In the configuration file, if you want to use a [default](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/pipeline/clean/run-opusfilter.py#13) configuration, you can see how in [this example](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/configs/opusfilter/config.fiu-eng.opusfilter.yml#L33). Otherwise, you can specify the path to a specific file with an Opusfilter configuration such as [this one](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/configs/opusfilter/config.opusfilter.yml).

```yaml
  opusfilter:
    config: default # Otherwise, specify path to opusfilter configuration 'configs/opusfilter/config.opusfilter.yaml'
```

### Bicleaner AI

At the moment, this is not working.

## Teacher models

At the moment, the type of teacher models available are only OPUS-MT (HuggingFace models coming soon!).

It is defined by:

* `opusmt-teacher`

This can be either of the following:
1. the URL to an OPUS-MT model

```yaml
  opusmt-teacher: "https://object.pouta.csc.fi/Tatoeba-MT-models/fiu-eng/opus4m-2020-08-12.zip"
```

2. the path to an OPUS-MT model, 
```yaml
  opusmt-teacher: "/path/to/opus-mt/model"
```

3. a list of OPUS-MT models that will be used all together (any combination of the previous two).

```yaml
  opusmt-teacher:
    - "https://object.pouta.csc.fi/Tatoeba-MT-models/gem-gem/opus-2020-10-04.zip"
    - "https://object.pouta.csc.fi/Tatoeba-MT-models/eng-swe/opus+bt-2021-04-14.zip"
```


4. In the case of multilingual students, you can combine different teachers. In this case, it should be a dictionary, specifying each teacher per language pair.

```yaml
  opusmt-teacher:
    en-uk: "https://object.pouta.csc.fi/Tatoeba-MT-models/eng-ukr/opus+bt-2021-04-14.zip"
    en-ru: "https://object.pouta.csc.fi/Tatoeba-MT-models/eng-rus/opus+bt-2021-04-14.zip"
    en-be: "https://object.pouta.csc.fi/Tatoeba-MT-models/eng-bel/opus+bt-2021-03-07.zip"
```

5. `best` which will select the best teacher available for each language pair by checking the FLORES200+ scores from the [OPUS-MT dashboard](https://opus.nlpl.eu/dashboard).

```yaml
  opusmt-teacher: "best"
```

## Backward models

At the moment, the type of teacher models available are only OPUS-MT (HuggingFace models coming soon!).

It is defined by:

* `opusmt-backward`: the URL or path to an OPUS-MT model to be used as a backward model for scoring translations. As the teacher, it can also be a dictionary specifying a backward model per language pair as well as `best`.

```yaml
  opusmt-backward:
    uk-en: "https://object.pouta.csc.fi/Tatoeba-MT-models/ukr-eng/opus+bt-2021-04-30.zip"
    ru-en: "https://object.pouta.csc.fi/Tatoeba-MT-models/rus-eng/opus+bt-2021-04-30.zip"
    be-en: "https://object.pouta.csc.fi/Tatoeba-MT-models/bel-eng/opus+bt-2021-04-30.zip"
```

## Multilinguality
Specify if the teacher, the backward and the student models are many-to-one to be able to deal properly with language tags. By default, this is  `False`.

* `one2many-teacher`: `True` or `False` (default). If `opusmt-teacher` is "best", then this should be also "best"
* `one2many-backward`: `True` or `False` (default). If `opusmt-backward` is "best", then this should be also "best"
* `one2many-student`: `True` or `False` (default). 

```yaml
# Specify if the teacher and the student are many2one
  one2many-teacher: True
  one2many-student: True
```
## Training

### Marian arguments
These configs override pipeline/train/configs with [Marian settings](https://marian-nmt.github.io/docs/cmd/marian/)

The options are: `training-teacher`, `decoding-teacher`,`training-backward`, `decoding-backward`,`training-student`, `training-student-finetuned`

```yaml
  marian-args:
  #these configs override pipeline/train/configs
  training-student:
    dec-depth: 3
    enc-depth: 3
    dim-emb: 512
    tied-embeddings-all: true
    transformer-decoder-autoreg: rnn
    transformer-dim-ffn: 2048
    transformer-ffn-activation: relu
    transformer-ffn-depth: 2
    transformer-guided-alignment-layer: last
    transformer-heads: 8
    transformer-postprocess: dan
    transformer-preprocess: ""
    transformer-tied-layers: []
    transformer-train-position-embeddings: false
    type: transformer
```

### Opustrainer

We have also added support for using [OpusTrainer](https://github.com/hplt-project/OpusTrainer), a tool for curriculum training and data augmentation. 

In the configuration file, you can specify a path to the OpusTrainer configuration as in [here](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/opustrainer/config.fiu-eng.opustrainer.yml#L37). However, this assumes that you already now the final paths of the data as specified in [here](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/opustrainer/config.fiu-eng.opustrainer.stages.yml).

At the moment, this is only implemented for student training.

```yaml
  opustrainer:
    model: student # Ideally, could be teacher or backward
    path: "configs/opustrainer/config.fiu-eng.opustrainer.stages.yml" # This assumes you already know the paths to the data
```

### Other

* `parallel-max-sentences`: maximum parallel sentences to download from each dataset.
* `split-length`: the amount of sentences into which you want to split your training data for forward translation.
* `best-model`: metric to select your best model.
* `spm-sample-size`: sample size to train spm vocabulary of the student.
* `student-prefix`: in case you want to train multiple students with exactly the same data, you can add this prefix which will allow you to train multiple students in the same directory structure. Find more about the directory structure [here](../pipeline/dir_structure.md).
