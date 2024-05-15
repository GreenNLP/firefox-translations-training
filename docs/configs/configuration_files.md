# Configuration files

Configuration files are in [YAML](https://yaml.org/) format.
At the top level, they have two sections:

* `experiment`: contains all the relevant information for your experiment, except the information on which datasets to use.
* `datasets`: contains the infromation regarding the datasets used for training, development and evaluation.

Within `experiment` you should define at least the following:

* `dirname`: directory name where everything will be stored.
* `name`: name of the experiment you are running. All generated data and models will be stored in `dirname`/`name`
* `langpairs`: a list of the language pairs you want in your student model, with **two letter codes**