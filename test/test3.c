extern int printf(char str, int agr1, int arg2);

extern int puts(char str);

extern int scanf(char str, int arg1);

struct Point
{
    double x;
    int y;
};

double func(struct Point p);

struct Point p_global[3];

int main()
{
    struct Point p;
    struct Point p_local[3];
    int a;
    char input[32];
    p.x = 1.5;
    p.y = 3;
    scanf("%s", input);
    printf("%s = %lf", input, func(p));
    puts("");
    p_global[0].x = 3.1415926;
    p_global[0].y = 2;
    p_local[0].x = 2.71828;
    p_local[0].y = 1;
    printf("p_global.x = %lf, p_global.y = %d", p_global[0].x, p_global[0].y);
    puts("");
    printf("p_local.x = %lf, p_local.y = %d", p_local[0].x, p_local[0].y);
    puts("");

    return 0;
}

double func(struct Point p)
{
    return p.x + p.y;
}
