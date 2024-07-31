import logging
import azure.functions as func
import requests
import json


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    data = ""
    try:
        response = requests.get('https://api.coindesk.com/v1/bpi/currentprice.json')
        data = response.json()
        print(data)

        func.HttpResponse.mimetype = 'application/json'
        func.HttpResponse.charset = 'utf-8'

        return func.HttpResponse(json.dumps(data), status_code=200)
    except:
        pass

    data = "invalid response from coindesk api"

    func.HttpResponse.mimetype = 'text/plain'
    func.HttpResponse.charset = 'utf-8'

    return func.HttpResponse(data, status_code=503)