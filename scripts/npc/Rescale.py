def printscale(a, scale):
    print(f'{round(a,2)} {round(a+scale,2)} {round(a+2*scale,2)} {round(a+3*scale,2)} {round(a+4*scale,2)} {round(a+5*scale,2)} {round(a+6*scale,2)}')

while True:
    print('a = ?')
    a = float(input())
    print('b = ?')
    b = float(input())
    print('scale = ?')
    scale = float(input())

    if a == 0:
        a = b-6*scale
        printscale(a, scale)
    elif b == 0:
        printscale(a, scale)
    elif scale == 0:
        scale = (b-a)/6
        printscale(a, scale)