extern int printf(char str, int agr1, int arg2);

extern int puts(char str);

extern int scanf(char str, int arg1);

struct Point
{
    double x;
    int y;
};

double func(struct Point p);

struct Point p_global;

//float fuck;

int main()
{
    struct Point p;
    int a;
    char input[32];
    p.x = 1.5;
    p.y = 3;
    scanf("%s", input);
    printf("%s = %lf", input, func(p));
    puts("");
    p_global.x = 4.3;
    p_global.y = 5;
    printf("p_global.x = %lf, p_global.y = %d", p_global.x, p_global.y);
    puts("");

    return 0;
}

double func(struct Point p)
{
    return p.x + p.y;
}
