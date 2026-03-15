import os
import subprocess

def run_analyze():
    try:
        result = subprocess.run(['flutter', 'analyze', '--no-fatal-infos'], capture_output=True, text=True)
        with open('clean_analyze.txt', 'w', encoding='utf-8') as f:
            f.write(result.stdout)
            f.write(result.stderr)
    except Exception as e:
        with open('clean_analyze.txt', 'w', encoding='utf-8') as f:
            f.write(str(e))

if __name__ == "__main__":
    run_analyze()
