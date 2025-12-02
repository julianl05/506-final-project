.PHONY: help setup install data clean test all check-data check-system

# Default target - show help
help:
	@echo "Blue Bikes Demand Prediction - Makefile"
	@echo "========================================"
	@echo ""
	@echo "Available targets:"
	@echo "  make all         - Complete setup: environment + deps + data validation"
	@echo "  make setup       - Create virtual environment and install dependencies"
	@echo "  make install     - Install/update Python dependencies only"
	@echo "  make data        - Generate calendar features CSV"
	@echo "  make check-data  - Validate that all required data files exist"
	@echo "  make check-system - Check system dependencies (OpenMP for XGBoost)"
	@echo "  make test        - Run test suite"
	@echo "  make clean       - Remove generated files and caches"
	@echo ""
	@echo "Quick start for reproducing results:"
	@echo "  1. make all"
	@echo "  2. Open VS Code and run notebooks in order:"
	@echo "     - notebooks/process_data.ipynb"
	@echo "     - notebooks/linear_modeling.ipynb"
	@echo ""

# Complete setup: environment, dependencies, and data validation
all: setup check-system data check-data
	@echo ""
	@echo "=========================================="
	@echo "✓ Setup complete!"
	@echo "=========================================="
	@echo ""
	@echo "Next steps:"
	@echo "  1. Activate environment:"
	@echo "       source venv/bin/activate"
	@echo ""
	@echo "  2. Open VS Code and run notebooks in order:"
	@echo "       - notebooks/process_data.ipynb"
	@echo "       - notebooks/linear_modeling.ipynb"
	@echo ""

# Check system dependencies (OpenMP for XGBoost on macOS)
check-system:
	@echo "Checking system dependencies..."
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "  Detected macOS - checking for OpenMP (required for XGBoost)..."; \
		if [ -d "/opt/homebrew/opt/libomp" ] || [ -d "/usr/local/opt/libomp" ]; then \
			echo "  ✓ OpenMP found"; \
		else \
			echo "  ✗ OpenMP not found"; \
			echo ""; \
			echo "  XGBoost requires OpenMP on macOS. Install with:"; \
			echo "    brew install libomp"; \
			echo ""; \
			echo "  If you don't have Homebrew, install it first:"; \
			echo "    /bin/bash -c \"\$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""; \
			echo ""; \
			exit 1; \
		fi; \
	else \
		echo "  ✓ Non-macOS system (OpenMP typically pre-installed on Linux)"; \
	fi

# Create virtual environment and install dependencies
setup: check-system
	@echo "Creating Python virtual environment..."
	python3 -m venv venv
	@echo "Installing dependencies..."
	./venv/bin/pip install --upgrade pip
	./venv/bin/pip install pandas numpy matplotlib seaborn scikit-learn xgboost holidays jupyter contextily pyproj itertools
	@echo "✓ Virtual environment created and dependencies installed"
	@echo ""
	@echo "To activate: source venv/bin/activate"

# Install dependencies only (for when venv already exists)
install: check-system
	@echo "Installing/updating dependencies..."
	./venv/bin/pip install --upgrade pip
	./venv/bin/pip install pandas numpy matplotlib seaborn scikit-learn xgboost holidays jupyter contextily pyproj
	@echo "✓ Dependencies installed"

# Generate calendar features CSV
data:
	@echo "Generating calendar features..."
	@mkdir -p data/raw/dates
	./venv/bin/python scripts/getCalendarFeatures.py
	@if [ -f data/raw/calendar_features.csv ]; then \
		mv data/raw/calendar_features.csv data/raw/dates/calendar_features.csv 2>/dev/null || true; \
	fi
	@echo "✓ Calendar features generated at data/raw/dates/calendar_features.csv"

# Validate data structure and required files
check-data:
	@echo ""
	@echo "=========================================="
	@echo "DATA VALIDATION"
	@echo "=========================================="
	@echo ""
	@echo "Creating directory structure..."
	@mkdir -p data/raw/trips/2022 data/raw/trips/2023 data/raw/trips/2024 data/raw/trips/2025
	@mkdir -p data/raw/stations data/raw/weather data/raw/dates
	@mkdir -p data/processed
	@mkdir -p visualizations
	@echo "✓ Directory structure validated"
	@echo ""
	@echo "Checking required files:"
	@echo ""
	@if [ -f data/raw/dates/calendar_features.csv ]; then \
		echo "  ✓ data/raw/dates/calendar_features.csv"; \
	else \
		echo "  ✗ data/raw/dates/calendar_features.csv"; \
		echo "    → Run 'make data' to generate"; \
	fi
	@if [ -f "data/raw/weather/open-meteo-42.36N71.13W19m (2).csv" ]; then \
		echo "  ✓ data/raw/weather/open-meteo-42.36N71.13W19m (2).csv"; \
	else \
		echo "  ✗ data/raw/weather/open-meteo-42.36N71.13W19m (2).csv"; \
		echo "    → Download from: https://open-meteo.com/en/docs/historical-weather-api"; \
	fi
	@if [ -f "data/raw/stations/-External-_Bluebikes_Station_List - current_bluebikes_stations (2).csv" ]; then \
		echo "  ✓ data/raw/stations/station list CSV"; \
	else \
		echo "  ✗ data/raw/stations/station list CSV"; \
		echo "    → Download from Blue Bikes system data portal"; \
	fi
	@echo ""
	@trip_count=$$(find data/raw/trips -name "*.csv" 2>/dev/null | wc -l | tr -d ' '); \
	if [ $$trip_count -eq 0 ]; then \
		echo "  ✗ No trip data found (need 45 CSV files for Jan 2022 - Sep 2025)"; \
		echo "    → Download from: https://www.bluebikes.com/system-data"; \
		echo "    → Place in: data/raw/trips/{year}/ directories"; \
	elif [ $$trip_count -lt 45 ]; then \
		echo "  ⚠  Found $$trip_count trip files (expected 45 for Jan 2022 - Sep 2025)"; \
	else \
		echo "  ✓ Found $$trip_count trip data files"; \
	fi
	@echo ""
	@echo "=========================================="

# Run tests
test:
	@echo "Running test suite..."
	./venv/bin/python -m pytest tests/ -v

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -rf .ipynb_checkpoints
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ipynb_checkpoints" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	@echo "✓ Cleaned cache files"
	@echo ""
	@echo "Note: Processed data and visualizations preserved"
	@echo "      To remove, delete data/processed/ and visualizations/ manually"

# Deep clean - remove everything including venv
clean-all: clean
	@echo "Removing virtual environment..."
	rm -rf venv
	@echo "✓ Complete cleanup finished"