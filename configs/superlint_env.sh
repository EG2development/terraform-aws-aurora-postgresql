#!/bin/bash
# See https://github.com/super-linter/super-linter#environment-variables
# VALIDATE_<LANGUAGE> enviroment variables only add linters you DO NOT need. All other linters will default to true.
{
	echo "VALIDATE_PYTHON_MYPY=false"              # Pylint/black/flake8 used instead
	echo "VALIDATE_JSCPD=false"                    # Optional should be enabled/disabled on a per repo basis
	echo "VALIDATE_PYTHON_ISORT=false"             # Pylint/black/flake8 used instead
	echo "VALIDATE_NATURAL_LANGUAGE=false"         # Optional should be enabled/disabled on a per repo basis
	echo "VALIDATE_DOCKERFILE_HADOLINT=false"      # Optional should be enabled/disabled on a per repo basis
	echo "VALIDATE_TERRAFORM_TERRASCAN=false"      # tflint/checkov used instead
	echo "VALIDATE_TERRAFORM_FMT=false"            # hashicorp action used instead
	echo "VALIDATE_GO=false"                       #  bug in superlinter see https://github.com/ONSdigital/catd-github-actions/blob/main/docs/known-issues.md
	echo "FILTER_REGEX_EXCLUDE=.*/terraform/.*.md" # Skip terraform docs files for markdown linter
	echo "SHELLCHECK_OPTS=-e SC2046 -e SC2086"     #  bug in superlinter see https://github.com/ONSdigital/catd-github-actions/blob/main/docs/known-issues.md
	echo "VALIDATE_TERRAGRUNT=false"               # Might not work with 1.7.0?
	echo "VALIDATE_TERRAFORM_TFLINT=false"         # tflint has it's own workflow now
	echo "VALIDATE_CHECKOV=false"                  # checkov in superlinter doesn't allow config file paths, so we have our own workflow
	echo "VALIDATE_JS_PRETTIER=false"              # Disable Prettier conflicts with StandardJS
	echo "VALIDATE_PYTHON_RUFF=false"              # Pylint/black/flake8 used instead
	echo "VALIDATE_PYTHON_RUFF_FORMAT=false"       # Pylint/black/flake8 used instead
	echo "VALIDATE_BIOME_FORMAT=false"             # Prettier used instead
	echo "VALIDATE_BIOME_LINT=false"               # Prettier used instead
	echo "VALIDATE_GITHUB_ACTIONS_ZIZMOR=false"    # need to do discuss further
} >>$GITHUB_ENV
