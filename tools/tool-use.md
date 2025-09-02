# Tool Usage Guide

## UI Review Tool (ui-review-browser.py)
AI-powered UI/UX analysis of web pages

### Basic Usage
```bash
python ui-review-browser.py <url>
```

### Options
- `--headed` - Show browser (default: headless)
- `--element <selector>` - Review specific CSS element
- `--save <path>` - Save screenshot
- `--model <model>` - OpenAI model (default: gpt-4o-mini)
- `--prompt <text>` - Custom analysis prompt
- `--wait <seconds>` - Page load wait time (default: 3)

### Examples
```bash
# Basic review
python ui-review-browser.py https://example.com

# Review with visible browser
python ui-review-browser.py https://example.com --headed

# Review specific element
python ui-review-browser.py https://example.com --element "#header"

# Custom analysis
python ui-review-browser.py https://example.com --prompt "Focus on accessibility"
```

## JS Error Checker (jscheck)
Detect JavaScript errors on web pages

### Basic Usage
```bash
jscheck <url>
```

### Options
- `--timeout <seconds>` - Page timeout (default: 30)
- `--wait <seconds>` - Wait after load (default: 5)
- `--output <format>` - json|text (default: text)

### Examples
```bash
# Check for JS errors
jscheck https://example.com

# JSON output
jscheck https://example.com --output json

# Custom timeouts
jscheck https://example.com --timeout 60 --wait 10
```

## Environment Setup
Both tools require:
```bash
export OPENAI_API_KEY="your-key"
pip install -r requirements.txt
```