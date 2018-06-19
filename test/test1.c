extern int printf(char str, int format);

extern int puts(char str);

int func(int i)
{
    int a;
    return 1;
}

int main()
{
    int x;
    int y;
    int z;

    x = 12;
    x[1] = 13;
    y = x + 22 + (2.3 & 2.4);   /* load value of x that was just stored */
    w = y + 33;                 /* load value of y that was just stored */

    printf("x = %d", x);
    puts("");
    printf("y = %d", y);
    puts("");
    printf("z = %d", z);
    puts("");

    func(1, 2);
    return 0;
}