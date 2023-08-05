import json
import logging
import os
import random
from typing import Union

import logging_loki
import requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, status
from pydantic import BaseModel

# Load environment variables
load_dotenv()
RPC_PROVIDERS = os.getenv("RPC_PROVIDERS_HTTP", "").split(",")
TIMEOUT_SECONDS = int(os.getenv("TIMEOUT_SECONDS", 5))
LOG_FILE = os.getenv("LOG_FILE", False)
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOKI_URL = os.getenv("LOKI_URL", False)
LOKI_USER = os.getenv("LOKI_USER", False)
LOKI_PASSWORD = os.getenv("LOKI_PASSWORD", False)

# Error out if no rpc providers are defined
if not RPC_PROVIDERS[0]:
    raise Exception("RPC_PROVIDERS not defined in environment")

# Configure logging
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

if LOG_FILE:
    file_handler = logging.FileHandler(LOG_FILE)
    file_formatter = logging.Formatter(
        json.dumps(
            {
                "time": "%(asctime)s",
                "level": "%(levelname)s",
                "message": "%(message)s",
            }
        )
    )
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)

if LOKI_URL:
    logging_loki.emitter.LokiEmitter.level_tag = "level"
    loki_handler = logging_loki.LokiHandler(
        url=LOKI_URL,
        version="1",
        tags={"application": "pyeth-proxy"},
        auth=(LOKI_USER, LOKI_PASSWORD),
    )
    logger.addHandler(loki_handler)


stream_handler = logging.StreamHandler()
stream_formatter = logging.Formatter("%(asctime)-15s %(levelname)-8s %(message)s")
stream_handler.setFormatter(stream_formatter)
logger.addHandler(stream_handler)

app = FastAPI()
logger.info("Started pyeth-proxy")


class JsonRpcBody(BaseModel):
    """Model for request body"""

    jsonrpc: float
    method: str
    params: list
    id: Union[int, str] | None = None


class HealthCheck(BaseModel):
    """Response model to validate and return when performing a health check"""

    status: str = "OK"


@app.get(
    "/health",
    response_description="Return HTTP Status Code 200 (OK)",
    status_code=status.HTTP_200_OK,
    response_model=HealthCheck,
)
def get_health() -> HealthCheck:
    """
    Returns a JSON response with the health status
    """
    return HealthCheck(status="OK")


@app.post("/")
async def handle_request(json_rpc_body: JsonRpcBody, request: Request):
    """
    Receives a post request expecting data in Ethereum json rpc format. Forwards the request to a node provider. If an
    error occurs, the request is retried with a different provider.
    """

    logger.info(
        "Received request",
        extra={
            "tags": {
                "body": f"'{json_rpc_body.model_dump_json()}'",
                "source": request.client.host,
            }
        },
    )

    # create a list of possible indexes of providers
    indexes = list(range(len(RPC_PROVIDERS)))
    exceptions = []
    while indexes:
        try:
            # select a random provider to serve the request
            index = random.choice(indexes)
            url = RPC_PROVIDERS[index]
            response = requests.post(
                url,
                data=json_rpc_body.model_dump_json(),
                headers={"Content-Type": "application/json"},
                timeout=TIMEOUT_SECONDS,
            )
            logger.info(
                "Reveived response from node",
                extra={"tags": {"body": f"'{response.json()}'"}},
            )
            if "error" in response.json():
                raise Exception(response.json())
            response.raise_for_status()
            return response.json()
        except Exception as e:
            # append to a list of errors to return to the user
            message = str(e)
            logger.error(f"Exception occurred: {message}")
            exceptions.append(message)
            # drop the erroring provider for subsequent retries
            indexes.remove(index)

    # return list of errors to user
    raise HTTPException(detail={"errors": exceptions}, status_code=400)
