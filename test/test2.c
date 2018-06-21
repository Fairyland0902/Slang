extern int printf(char str, int src);

extern int puts(char str);

int main()
{
//    int arr[12] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
    int arr2[3][4][2] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24};

    int i;
    int j;
    int k;

//    for (i = 0; i < 3; i = i + 1)
//    {
//        for (j = 0; j < 4; j = j + 1)
//        {
//            arr2[i][j] = arr[i * 4 + j];
//        }
//    }

    for (i = 0; i < 3; i++)
    {
        for (j = 0; j < 4; j++)
        {
            for (k = 0; k < 2; k++)
            {
                arr2[i][j][k] *= 2;
                printf("%d,", arr2[i][j][k]);
            }
            puts("");
        }
        puts("");
    }
    return 0;
}