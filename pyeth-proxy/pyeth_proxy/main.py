import os
import random
from typing import Union

import requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Load environment variables
load_dotenv()
RPC_PROVIDERS = os.getenv("RPC_PROVIDERS_HTTP", "").split(",")
TIMEOUT_SECONDS = int(os.getenv("TIMEOUT_SECONDS", 5))


# Error out if no rpc providers are defined
if not RPC_PROVIDERS[0]:
    raise Exception("RPC_PROVIDERS not defined in environment")

app = FastAPI()


# Define request structure
class JsonRpcBody(BaseModel):
    jsonrpc: float
    method: str
    params: list
    id: Union[int, str] | None = None


@app.post("/")
async def handle_request(json_rpc_body: JsonRpcBody):
    """
    handle_request:
    Receives a post request expecting data in Ethereum json rpc format. Forwards the request to a node provider. If an
    error occurs, the request is retried with a different provider.
    """

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
                # headers={"Content-Type": "application/json"},
                timeout=TIMEOUT_SECONDS,
            )
            print(response.json())
            if "error" in response.json():
                raise Exception(response.json())
            response.raise_for_status()
            return response.json()
        except Exception as e:
            # append to a list of errors to return to the user
            message = str(e)
            print(f"Exception occurred: {message}")
            exceptions.append(message)
            # drop the erroring provider for subsequent retries
            indexes.remove(index)

    # return list of errors to user
    raise HTTPException(detail={"errors": exceptions}, status_code=400)
