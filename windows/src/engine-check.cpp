#include "engine.hpp"
#include <iostream>
int main(int argc,char** argv) {
    if(argc!=2)return 2;std::string dir=argv[1];std::ifstream cn(dir+"/chinese.tsv"),en(dir+"/english.txt"),abbr(dir+"/abbreviations.tsv");
    shunwei::Engine e;if(!e.load(cn,en,abbr))return 3;
    std::vector<std::pair<std::string,std::string>> cases={{"aizidongdazi","AI 自动打字"},{"woaini","我爱你"},{"nihao","你好"},{"jintiantianqihenhao","今天天气很好"},{"wo yong python xie daima","我用 Python 写代码"},{"https://example.com/a","https://example.com/a"},{"a@example.com","a@example.com"},{"foo_bar","foo_bar"},{"v1.2.3","v1.2.3"},{"xi'an","西安"}};
    int failed=0;
    for(auto& c:cases){auto candidates=e.decode(shunwei::wide(c.first));bool ok=std::find(candidates.begin(),candidates.end(),shunwei::wide(c.second))!=candidates.end();std::cout<<(ok?"PASS ":"FAIL ")<<c.first;for(auto&s:candidates)std::cout<<" | "<<shunwei::utf8(s);std::cout<<"\n";if(!ok)++failed;}
    auto mixed=e.decode(L"aizidongdazi",false);if(std::find(mixed.begin(),mixed.end(),L"AI 自动打字")==mixed.end())++failed;
    if(e.decode(L"",true).size()!=0)++failed;
    std::cout<<"Windows engine portable checks: "<<(cases.size()+2-failed)<<"/"<<(cases.size()+2)<<"\n";return failed?1:0;
}
