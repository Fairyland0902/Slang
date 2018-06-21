extern int printf(char str, int format);

extern int puts(char str);

int w;
double k[3];

int main()
{
    int x;
    int y;
    int z;
    int kk[3] = {2, 3, 4};

    x = 12;
    y = -x + 22;   /* load value of x that was just stored */
    y /= -2;
    z = y + 33;   /* load value of y that was just stored */
    w = z + 44;

    printf("x = %d", x);
    puts("");
    printf("y = %d", y);
    puts("");
    printf("z = %d", z);
    puts("");
    printf("w = %d", w);
    puts("");
    int i;
    for (i = 0; i < 3; ++i)
    {
        k[i] = i / 3.0;
        printf("k[i] = %lf", k[i]);
        puts("");
        printf("kk[i] = %d", kk[i]);
        puts("");
    }

    return 0;
}