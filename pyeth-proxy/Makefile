install:
	poetry install

lint:
	poetry run black pyeth_proxy/
	poetry run isort pyeth_proxy/

run:
	poetry run uvicorn pyeth_proxy.main:app
