import logging
import random
import azure.functions as func

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('calculates pi to n decimal places...')

    num = req.params.get('num')

    responseCode = 200
    random_num = random.random()

    # Randomize response code - simulate errors for azure app insights demo
    if random_num < 0.7:
        # GREEN
        responseCode = 200
    elif random_num < 0.9:
        # ORANGE
        responseCode = 403
    else:
        # RED
        responseCode = 503

    if responseCode == 200:
        if num:
            digits = [str(n) for n in list(pi_digits(int(num)))]
            pi = "%s.%s\n" % (digits.pop(0), "".join(digits))
            return func.HttpResponse(f"\n{pi}\n\n", status_code=responseCode)

        else:
            raise ValueError('glitch in the matrix...')
    else:
        raise ValueError('glitch in the matrix...')

def pi_digits(x):
    k,a,b,a1,b1 = 2,4,1,12,4
    while x > 0:
        p,q,k = k * k, 2 * k + 1, k + 1
        a,b,a1,b1 = a1, b1, p*a + q*a1, p*b + q*b1
        d,d1 = a/b, a1/b1
        while d == d1 and x > 0:
            yield int(d)
            x -= 1
            a,a1 = 10*(a % b), 10*(a1 % b1)
            d,d1 = a/b, a1/b1