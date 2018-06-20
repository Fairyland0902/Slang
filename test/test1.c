extern int printf(char str, int format);

extern int puts(char str);

int w = 1;

int main()
{
    int x;
    int y;
    int z;

    x = 12;
    y = x + 22;   /* load value of x that was just stored */
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

    return 0;
}