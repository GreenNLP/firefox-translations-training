from opusfilter.opusfilter import OpusFilter
import yaml
import sys

input_files = sys.argv[1].split()
filtered_files = sys.argv[2].split()
src_lang = sys.argv[3]
tgt_lang = sys.argv[4]
config_file = sys.argv[5]

if config_file == "default": #if a no configuration is given, use default
	filter_params = {
		'AlphabetRatioFilter': {},
		'LanguageIDFilter': {
			'id_method': 'cld2',
			'languages': [src_lang, tgt_lang]},
		'LengthRatioFilter.word': {
			'name': 'word',
			'unit': 'word'},
		'NonZeroNumeralsFilter': {},
		'TerminalPunctuationFilter': {},
			'RepetitionFilter': {}
		}
else:
	with open(config_file, 'r') as file:
		filter_params = yaml.safe_load(file)
	
config = {'steps': [
	        {'type': 'filter',
	            'parameters': {
		            'inputs': input_files,
		            'outputs': filtered_files,
                    'filters': [filter_params]}
                }
	        ]
	    }

of = OpusFilter(config)
of.execute_steps()