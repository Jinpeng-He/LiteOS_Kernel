#include <stdio.h>
#include <stdlib.h>


#define IF_ELSE(mask, if_do, else_do) if(uwSize & (mask)){if_do}else{else_do}
// cppcheck-suppress *
#define BIT_NUM(num) return num;
#define BIT_NONE BIT_NUM(0xfffffff)

STATIC_INLINE unsigned int LOS_Log2(unsigned int uwSize)
{
    IF_ELSE(0x80000000, \
			BIT_NONE, \
            IF_ELSE(0x7fff0000, \
                    IF_ELSE(0x7f000000,\
                            IF_ELSE(0x70000000,\
                                    IF_ELSE(0x40000000,\
                                            BIT_NUM(30),\
                                            IF_ELSE(0x20000000, BIT_NUM(29), BIT_NUM(28))), \
                                    IF_ELSE(0x0c000000, \
                                            IF_ELSE(0x08000000, BIT_NUM(27), BIT_NUM(26)), \
                                            IF_ELSE(0x02000000, BIT_NUM(25), BIT_NUM(24)))), \
                            IF_ELSE(0x00f00000, \
                                    IF_ELSE(0x00c00000, \
                                            IF_ELSE(0x00800000, BIT_NUM(23), BIT_NUM(22)), \
                                            IF_ELSE(0x00200000, BIT_NUM(21), BIT_NUM(20))), \
                                    IF_ELSE(0x000c0000,\
                                            IF_ELSE(0x00080000, BIT_NUM(19), BIT_NUM(18)), \
                                            IF_ELSE(0x00020000, BIT_NUM(17), BIT_NUM(16))))), \
                    IF_ELSE(0x0000ff00, \
                            IF_ELSE(0x0000f000, \
                                    IF_ELSE(0x0000c000, \
                                            IF_ELSE(0x00008000, BIT_NUM(15), BIT_NUM(14)), \
                                            IF_ELSE(0x00002000, BIT_NUM(13), BIT_NUM(12))), \
                                    IF_ELSE(0x00000c00, \
                                            IF_ELSE(0x00000800, BIT_NUM(11), BIT_NUM(10)), \
                                            IF_ELSE(0x00000200, BIT_NUM(9), BIT_NUM(8)))), \
                            IF_ELSE(0x000000f0, \
                                    IF_ELSE(0x000000c0, \
                                            IF_ELSE(0x00000080, BIT_NUM(7), BIT_NUM(6)), \
                                            IF_ELSE(0x00000020, BIT_NUM(5), BIT_NUM(4))), \
                                    IF_ELSE(0x0000000c, \
                                            IF_ELSE(0x00000008, BIT_NUM(3), BIT_NUM(2)), \
                                            IF_ELSE(0x00000002, BIT_NUM(1), BIT_NUM(0)))))))\

}



int main()
{
	unsigned int test1 = LOS_Log2(1);
	unsigned int test2 = LOS_Log2(4);
	unsigned int test3 = LOS_Log2(8);
	unsigned int test4 = LOS_Log2(9);
	unsigned int test5 = LOS_Log2(16);
	printf("test1=%d,test2=%d,test3=%d,test4=%d,test5=%d",test1,test2,test3,test4,test5);
	return 0;
}