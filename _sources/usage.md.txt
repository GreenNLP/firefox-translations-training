# Basic usage

## Running

Load all the necessary modules as explained in [Installation](installation.md)

Dry run first to check that everything was installed correctly:

```
make dry-run
```

To run the pipeline:
```
make run
```

To test the whole pipeline end to end (it is supposed to run relatively quickly and does not train anything useful):

```
make test
```
You can also run a speicific profile or config by overriding variables from Makefile
```
make run PROFILE=slurm-moz CONFIG=configs/config.test.yml
```

### Specific target

By default, all Snakemake rules are executed. To run the pipeline up to a specific rule use:
```
make run TARGET=<non-wildcard-rule-or-path>
```
For example, collect corpus first:
```
make run TARGET=merge_corpus
```

You can also use the full file path, for example:
```
make run TARGET=/models/ru-en/bicleaner/teacher-base0/model.npz.best-ce-mean-words.npz
```
### Rerunning

If you want to rerun a specific step or steps, you can delete the result files that are expected in the Snakemake rule output.
Snakemake might complain about a missing file and suggest to run it with `--clean-metadata` flag. In this case run:
```
make clean-meta TARGET=<missing-file-name>
```
and then as usual:
```
make run
```
