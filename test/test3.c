extern int printf(char str);

extern int puts(char str);

extern int scanf(char str);

struct Point
{
    int x;
    int y;
};

int func(struct Point p)
{
    return p.x;
}

int main()
{
    struct Point p;
    int a;
    char input[32];
    p.x = 1;
    p.y = 3;
    p.z = 4;
    scanf("%s", input);
    printf("%s = %d", input, func(p));
    puts("");
    return 0;
}
