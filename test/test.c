extern int printf(char format);
extern int puts(char s);

int main()
{
    int i = 1;
    printf("i=%d", i);
    puts("");
    i = i + 1;
    printf("i=%d", i);
    puts("");

    return 0;
}