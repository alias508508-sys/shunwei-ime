#pragma once
#include <algorithm>
#include <cmath>
#include <codecvt>
#include <fstream>
#include <locale>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

namespace shunwei {
inline std::wstring wide(const std::string& s) { return std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>>().from_bytes(s); }
inline std::string utf8(const std::wstring& s) { return std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>>().to_bytes(s); }
struct Word { std::wstring text; std::string pin; int frequency; std::string pos; std::vector<int> boundaries; };
struct Part { std::wstring output; int kind; std::string pos; }; // 0 literal, 1 pinyin, 2 English, 3 abbreviation
struct Path { std::vector<Part> parts; double score=0; };
inline std::wstring render(const Path& p) {
    std::wstring out;
    for(size_t i=0;i<p.parts.size();++i) {
        const auto& s=p.parts[i];
        bool space=!s.output.empty()&&s.output.find_first_not_of(L" \t\r\n")==std::wstring::npos;
        if(s.kind==0&&space) {
            int before=0,after=0;
            for(int j=int(i)-1;j>=0;--j)if(p.parts[j].kind){before=p.parts[j].kind;break;}
            for(size_t j=i+1;j<p.parts.size();++j)if(p.parts[j].kind){after=p.parts[j].kind;break;}
            if(before==1&&after==1)continue;
        }
        if(i&&p.parts[i-1].kind&&s.kind&&((p.parts[i-1].kind==1)!=(s.kind==1)))out+=L' ';
        out+=s.output;
    }
    return out;
}
inline void prune(std::vector<Path>& v) {
    std::stable_sort(v.begin(),v.end(),[](const Path&a,const Path&b){return a.score>b.score;});
    std::set<std::wstring> seen;std::map<int,int> groups;std::vector<Path> out;
    for(auto& p:v){auto text=render(p);if(!seen.insert(text).second)continue;int mask=0;for(auto&s:p.parts)mask|=s.kind==1?1:s.kind>=2?2:0;if(groups[mask]>=16)continue;++groups[mask];out.push_back(std::move(p));if(out.size()==32)break;}
    v=std::move(out);
}
class Engine {
    std::unordered_map<std::string,std::vector<Word>> words;
    std::set<std::string> english;
    std::map<std::string,std::wstring> abbreviations;
    std::set<std::string> common;
public:
    bool ready=false;
    bool load(std::istream& chinese,std::istream& en,std::istream& abbr) {
        std::string line;
        while(std::getline(chinese,line)) {
            std::istringstream row(line);std::string text,pin,freq,pos;std::getline(row,text,'\t');std::getline(row,pin,'\t');std::getline(row,freq,'\t');std::getline(row,pos);
            if(text.empty()||pin.empty()||freq.empty())continue;
            Word w{wide(text),pin,std::stoi(freq),pos,{}};std::string key;
            for(char c:pin){if(c==' ')w.boundaries.push_back(int(key.size()));else key+=c;}
            auto& matches=words[key];int count=0;for(auto& old:matches)if(old.pin==pin)++count;if(count<8)matches.push_back(std::move(w));
        }
        while(std::getline(en,line))if(!line.empty())english.insert(line);
        while(std::getline(abbr,line)){auto tab=line.find('\t');if(tab!=std::string::npos)abbreviations[line.substr(0,tab)]=wide(line.substr(tab+1));}
        std::istringstream c("a i an am are as at be been but by can cat car code data do dog for from go had has have he her here him his how if in into is it its like me my no not of on one or our out she so some than that the their them then there these they this time to two up us use was we were what when where which who why will with work would you your hello world love good morning thanks today tomorrow please name test input automatic school student book computer apple music game happy yes and english");
        while(c>>line)common.insert(line);
        ready=!words.empty()&&!english.empty();return ready;
    }
    std::vector<std::wstring> decode(const std::wstring& raw,bool chineseMode=true) const {
        if(raw.empty())return {};if(!ready||raw.size()>256)return {raw};
        // Technical tokens are never converted; the first Windows build accepts ASCII pinyin.
        if(raw.find(L"://")!=std::wstring::npos||raw.find(L'@')!=std::wstring::npos||raw.find(L'_')!=std::wstring::npos||raw.find(L'/')!=std::wstring::npos||raw.find(L'\\')!=std::wstring::npos||raw.find_first_of(L"0123456789")!=std::wstring::npos)return {raw};
        std::string input;for(wchar_t c:raw){if(c>127)return {raw};input+=char(c>='A'&&c<='Z'?c+32:c);}
        std::vector<std::vector<Path>> paths(input.size()+1);paths[0].push_back({});
        auto letter=[](char c){return c>='a'&&c<='z';};
        for(size_t i=0;i<input.size();++i) {
            if(paths[i].empty())continue;prune(paths[i]);
            struct Edge {size_t end;Part part;double score;};std::vector<Edge> edges;
            if(letter(input[i])) {
                std::string key;std::vector<int> explicitBoundaries;
                for(size_t j=i;j<input.size()&&j<i+32;++j) {
                    if(input[j]=='\''){explicitBoundaries.push_back(int(key.size()));continue;}if(!letter(input[j]))break;
                    key+=input[j];auto found=words.find(key);if(found==words.end())continue;
                    for(const auto& w:found->second) {
                        bool valid=true;for(int b:explicitBoundaries)if(std::find(w.boundaries.begin(),w.boundaries.end(),b)==w.boundaries.end())valid=false;if(!valid)continue;
                        double score=key.size()*2+std::log(w.frequency+2)*.7-8+6*w.boundaries.size()*std::min(1.,std::log(w.frequency+2)/std::log(100.));
                        edges.push_back({j+1,{w.text,1,w.pos},score});
                    }
                }
                key.clear();for(size_t j=i;j<input.size()&&j<i+32&&letter(input[j]);++j) {
                    key+=input[j];auto a=abbreviations.find(key);bool known=common.count(key)!=0;
                    bool singleBoundary=(i==0||!letter(input[i-1]))&&(j+1==input.size()||!letter(input[j+1]));
                    if(a!=abbreviations.end()||(key.size()>=3&&english.count(key))||(known&&(key.size()>=2||singleBoundary)))
                        edges.push_back({j+1,{a!=abbreviations.end()?a->second:raw.substr(i,j-i+1),a!=abbreviations.end()?3:2,""},double(key.size()*2)-8+(known?8:0)+(a!=abbreviations.end()?8:0)-(chineseMode?2:0)});
                }
                edges.push_back({i+1,{raw.substr(i,1),0,""},-4});
            } else edges.push_back({i+1,{raw.substr(i,1),0,""},0});
            for(const auto& e:edges) {
                for(auto p:paths[i]){
                    const Part* prev=nullptr;for(auto it=p.parts.rbegin();it!=p.parts.rend();++it)if(it->kind){prev=&*it;break;}
                    double bonus=0;
                    if(e.part.kind==1){if(e.part.pos=="q"&&(!prev||prev->pos!="m"))bonus-=2;if(prev&&!prev->pos.empty()&&prev->pos[0]=='v'&&!e.part.pos.empty()&&e.part.pos[0]=='n')bonus+=2;if(prev&&prev->pos=="r"&&!e.part.pos.empty()&&e.part.pos[0]=='v')bonus+=1;}
                    double cost=!p.parts.empty()&&p.parts.back().kind&&e.part.kind&&((p.parts.back().kind==1)!=(e.part.kind==1))?1:0;
                    p.parts.push_back(e.part);p.score+=e.score-cost+bonus;paths[e.end].push_back(std::move(p));
                }
                if(paths[e.end].size()>256)prune(paths[e.end]);
            }
        }
        auto final=paths.back();prune(final);std::vector<std::wstring> out;
        if(!chineseMode&&(english.count(input)||common.count(input))&&!abbreviations.count(input))out.push_back(raw);
        for(const auto& p:final){auto s=render(p);if(s!=raw&&std::find(out.begin(),out.end(),s)==out.end())out.push_back(s);if(out.size()==4)break;}
        // Preserve one mixed interpretation even when Chinese-priority homophones fill the first slots.
        for(const auto& p:final) {
            bool hasChinese=false,hasEnglish=false;
            for(const auto& part:p.parts){hasChinese|=part.kind==1;hasEnglish|=part.kind>=2;}
            if(!hasChinese||!hasEnglish)continue;
            auto mixed=render(p);
            if(mixed!=raw&&std::find(out.begin(),out.end(),mixed)==out.end()) {
                if(out.size()>=4)out.pop_back();
                out.insert(out.begin()+std::min<size_t>(1,out.size()),mixed);
            }
            break;
        }
        if(std::find(out.begin(),out.end(),raw)==out.end())out.push_back(raw);return out;
    }
};
}
