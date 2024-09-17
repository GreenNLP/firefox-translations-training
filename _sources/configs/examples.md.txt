# Examples of Configuration Files

Below are configuration examples to guide you in defining your own configurations.

## Multilinguality

The following table illustrates different distillation scenarios (o2m: one-to-many, m2o: many-to-one, m2m: many-to-many):

|ID | Configuration         | Teacher | Student | Example config                              |
|---|-----------------------|---------|---------|---------------------------------------------|
| 1 | bilingual - bilingual | en-et   | en-et   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/config.1.o2o.o2o.yml) | 
| 2 | o2m - bilingual       | eng-fiu | en-et   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/config.2.o2m.o2o.yml) |
| 3 | o2m - o2m             | eng-fiu | eng-fiu | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/config.3.o2m.o2m.yml) |
| 4 | m2o - bilingual       | fiu-eng | et-en   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/config.4.m2o.o2o.yml) |
| 5 | m2o - m2o             | fiu-eng | fiu-eng | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/config.5.m2o.m2o.yml) |
| 6 | m2m - bilingual       | fiu-gmw | et-en   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/config.6.m2m.o2o.yml) |
| 7 | m2m - o2m             | gmw-fiu | eng-fiu | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/config.7.m2m.o2m.yml) |
| 8 | m2m - m2o             | fiu-gmw | fiu-eng | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/config.8.m2m.m2o.yml) |
| 9 | m2m - m2m             | gmw-fiu | gmw-fiu | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/config.9.m2m.m2m.yml) |

## Data Processing

|ID | Configuration         | Teacher | Student | Example config                              |
|---|-----------------------|---------|---------|---------------------------------------------|
| 10 | OpusFilter | fiu-eng   | fiu-eng   | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/opusfilter/config.fiu-eng.opusfilter.yml) | 


## Training

|ID | Configuration         | Teacher | Student | Example config                              |
|---|-----------------------|---------|---------|---------------------------------------------|
| 11 | OpusTrainer | fiu-eng   | fiu-eng | [Config file](https://github.com/Helsinki-NLP/OpusDistillery/blob/main/configs/opustrainer/config.fiu-eng.opustrainer.yml) | 

