import logging
import azure.functions as func


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('calculates pi to n decimal places...')

    num = req.params.get('num')

    if num:
        digits = [str(n) for n in list(pi_digits(int(num)))]
        pi = "%s.%s\n" % (digits.pop(0), "".join(digits))
        return func.HttpResponse(f"\n{pi}\n\n", status_code=200)

    else:
        return func.HttpResponse(f"\n{0}\n\n", status_code=200)

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