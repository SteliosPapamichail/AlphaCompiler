
#include <iostream>
#include "symtable.h"
using namespace std;

int main(){
    SymTable_T test;

    cout<<SymTable_put(test,"nikos",1,LOCAL_,11)<<endl;
    cout<<SymTable_put(test,"nick",1,LIBFUNC_,222)<<endl;
    cout<<SymTable_put(test,"dave",2,LOCAL_,545)<<endl;

    cout<<"isactive: "<<SymTable_get(test,"nick",1)->isactive<<endl;
    SymTable_hide(test,1);
    
    cout<<SymTable_get(test,"dave",-1)->line<<endl;
    binding* tmp = SymTable_get(test,"nick",1);
    cout<<"isactive: "<<tmp->isactive<<endl;
    //cout<<tmp.empty()<<endl;
    return 0;
}