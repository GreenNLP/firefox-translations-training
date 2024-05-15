# Configuration files

Configuration files are in [YAML](https://yaml.org/) format.
At the top level, they have two sections:

* `experiment`: contains all the relevant information for your experiment, except the information on which datasets to use.
* `datasets`: contains the infromation regarding the datasets used for training, development and evaluation. Datasets are explained in [Dataset importers](docs/configs/downloading_and_selecting_data.md).

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

### Data processing
### opusfilter
### opustrainer

### Teacher models

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

### Backward model

At the moment, the type of teacher models available are only OPUS-MT (HuggingFace models coming soon!).

It is defined by:

* `opusmt-backward`: the URL or path to an OPUS-MT model to be used as a backward model for scoring translations. As the teacher, it can also be a dictionary specifying a backward model per language pair as well as `best`.

```yaml
  opusmt-backward:
    uk-en: "https://object.pouta.csc.fi/Tatoeba-MT-models/ukr-eng/opus+bt-2021-04-30.zip"
    ru-en: "https://object.pouta.csc.fi/Tatoeba-MT-models/rus-eng/opus+bt-2021-04-30.zip"
    be-en: "https://object.pouta.csc.fi/Tatoeba-MT-models/bel-eng/opus+bt-2021-04-30.zip"
```

### Multilinguality
Specify if the teacher, the backward and the student models are many-to-one to be able to deal properly with language tags. By default, this is  `False`.

* `one2many-teacher`: `True` or `False` (default). If `opusmt-teacher` is "best", then this should be also "best"
* `one2many-backward`: `True` or `False` (default). If `opusmt-backward` is "best", then this should be also "best"
* `one2many-student`: `True` or `False` (default). 

```yaml
# Specify if the teacher and the student are many2one
  one2many-teacher: True
  one2many-student: True
```

### Marian arguments
These configs override pipeline/train/configs with [Marian settings](https://marian-nmt.github.io/docs/cmd/marian/)

### Other

* `parallel-max-sentences`: maximum parallel sentences to download from each dataset.
* `split-length`: the amount of sentences into which you want to split your training data for forward translation.
* `best-model`: metric to select your best model.
* `spm-sample-size`: sample size to train spm vocabulary of the student.
* `student-prefix`: in case you want to train multiple students with exactly the same data, you can add this prefix which will allow you to train multiple students in the same directory structure.
