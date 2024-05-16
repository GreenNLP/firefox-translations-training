# Examples of Configuration Files

Next we provide some configuration examples that will guide you for defining your own.


## Multilinguality

The different possible distilling scenarios that we envision and that are covered are the following (o2m: one2many, m2o: many2one, m2m: many2many):

|ID | Configuration         | Teacher | Student | Example config                              |
|---|-----------------------|---------|---------|---------------------------------------------|
| 1 | bilingual - bilingual | en-et   | en-et   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/config.1.o2o.o2o.yml) | 
| 2 | o2m - bilingual       | eng-fiu | en-et   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/config.2.o2m.o2o.yml) |
| 3 | o2m - o2m             | eng-fiu | eng-fiu | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/config.3.o2m.o2m.yml) |
| 4 | m2o - bilingual       | fiu-eng | et-en   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/config.4.m2o.o2o.yml) |
| 5 | m2o - m2o             | fiu-eng | fiu-eng | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/config.5.m2o.m2o.yml) |
| 6 | m2m - bilingual       | fiu-gmw | et-en   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/config.6.m2m.o2o.yml) |
| 7 | m2m - o2m             | gmw-fiu | eng-fiu | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/config.7.m2m.o2m.yml) |
| 8 | m2m - m2o             | fiu-gmw | fiu-eng | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/config.8.m2m.m2o.yml) |
| 9 | m2m - m2m             | gmw-fiu | gmw-fiu | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/config.9.m2m.m2m.yml) |

## Data Processing

|ID | Configuration         | Teacher | Student | Example config                              |
|---|-----------------------|---------|---------|---------------------------------------------|
| 10 | OpusFilter | fiu-eng   | fiu-eng   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/opusfilter/config.fiu-eng.opusfilter.yml) | 


## Training

|ID | Configuration         | Teacher | Student | Example config                              |
|---|-----------------------|---------|---------|---------------------------------------------|
| 11 | OpusTrainer | fiu-eng   | fiu-eng | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/multi-ftt/configs/opustrainer/config.fiu-eng.opustrainer.yml) | 

