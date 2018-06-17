extern int printf(char format);

extern int puts(char s);

int func(int a, int b)
{
    int res = 0;
    if (a <= 1)
    {
        res = 1;
    } else if (1)
    {
        res = func(a - 1, b) + func(a - 2, b);
    } else
    {
        res = func(b, a);
    }
    return res;
}

int main(int argc, char[1] argv)
{
    int i;
    argc = 5;
    for (i = 1; i < argc; i = i + 1)
    {
        printf("i=%d, func=%d", i, func(i, argc));
        puts("");
    }

    return 0;
}