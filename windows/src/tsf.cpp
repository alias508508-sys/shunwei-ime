#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <msctf.h>
#ifndef __ITfTextInputProcessorEx_INTERFACE_DEFINED__
#define __ITfTextInputProcessorEx_INTERFACE_DEFINED__
static const IID IID_ITfTextInputProcessorEx={0x6e4e2102,0xf9cd,0x433d,{0xb4,0x96,0x30,0x3c,0xe0,0x3a,0x65,0x07}};
struct ITfTextInputProcessorEx: public ITfTextInputProcessor {
    virtual HRESULT STDMETHODCALLTYPE ActivateEx(ITfThreadMgr*,TfClientId,DWORD)=0;
};
#endif
#include <atomic>
#include <functional>
#include <filesystem>
#include <mutex>
#include "engine.hpp"

// MSVC must use the Windows SDK declaration's linkage for COM entry points.
#if defined(_MSC_VER)
#define SHUNWEI_COM_EXPORT STDAPI
#else
#define SHUNWEI_COM_EXPORT extern "C" __declspec(dllexport) HRESULT WINAPI
#endif

static const CLSID CLSID_ShUnwei={0x3db927ad,0xfa61,0x43e6,{0xb9,0xaf,0x3b,0xb5,0xcf,0xfa,0xd2,0xb8}};
static const GUID PROFILE_ShUnwei={0x8cfab146,0x88b9,0x4a5d,{0x92,0xe0,0x74,0x83,0x76,0x81,0xd1,0x22}};
static constexpr LANGID Language=0x0804;
static HMODULE moduleHandle=nullptr;
static std::atomic<long> objects{0},locks{0};
template<class T> void release(T*&p){if(p){p->Release();p=nullptr;}}
static std::wstring modulePath(){wchar_t path[32768];DWORD n=GetModuleFileNameW(moduleHandle,path,32768);return std::wstring(path,n);}
static const shunwei::Engine& engine(){static shunwei::Engine instance;static std::once_flag once;std::call_once(once,[&]{auto dir=std::filesystem::path(modulePath()).parent_path()/L"data";std::ifstream cn(dir/L"chinese.tsv"),en(dir/L"english.txt"),ab(dir/L"abbreviations.tsv");instance.load(cn,en,ab);});return instance;}
class EditSession:public ITfEditSession{
    std::atomic<ULONG> refs{1};std::function<HRESULT(TfEditCookie)> action;
public:
    explicit EditSession(std::function<HRESULT(TfEditCookie)>fn):action(std::move(fn)){++objects;}
    ~EditSession(){--objects;}
    STDMETHODIMP QueryInterface(REFIID id,void**out)override{if(!out)return E_POINTER;*out=nullptr;if(id==IID_IUnknown||id==IID_ITfEditSession)*out=static_cast<ITfEditSession*>(this);if(!*out)return E_NOINTERFACE;AddRef();return S_OK;}
    STDMETHODIMP_(ULONG) AddRef()override{return ++refs;}
    STDMETHODIMP_(ULONG) Release()override{ULONG n=--refs;if(!n)delete this;return n;}
    STDMETHODIMP DoEditSession(TfEditCookie cookie)override{return action(cookie);}
};
class Service:public ITfTextInputProcessorEx,public ITfKeyEventSink,public ITfCompositionSink,public ITfThreadMgrEventSink{
    std::atomic<ULONG> refs{1};ITfThreadMgr* manager=nullptr;TfClientId client=0;DWORD sinkCookie=TF_INVALID_COOKIE;
    ITfContext* context=nullptr;ITfComposition* composition=nullptr;std::wstring raw;size_t cursor=0,selected=0;
    std::vector<std::wstring> candidates;HWND panel=nullptr;bool secure=false;
    static LRESULT CALLBACK windowProc(HWND window,UINT message,WPARAM w,LPARAM l){
        auto* self=reinterpret_cast<Service*>(GetWindowLongPtrW(window,GWLP_USERDATA));
        if(message==WM_MOUSEACTIVATE)return MA_NOACTIVATE;
        if(self&&message==WM_LBUTTONDOWN){size_t index=static_cast<size_t>((short(HIWORD(l))-6)/34);if(index<self->candidates.size()){self->selected=index;self->request(self->context,[self](TfEditCookie c){return self->finish(c,self->candidates[self->selected]);});}return 0;}
        if(self&&message==WM_PAINT){PAINTSTRUCT ps;HDC dc=BeginPaint(window,&ps);RECT rect;GetClientRect(window,&rect);FillRect(dc,&rect,reinterpret_cast<HBRUSH>(COLOR_WINDOW+1));SetBkMode(dc,TRANSPARENT);HFONT font=CreateFontW(-18,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Segoe UI");auto previous=SelectObject(dc,font);
            for(size_t i=0;i<self->candidates.size();++i){RECT row{5,LONG(6+i*34),455,LONG(38+i*34)};if(i==self->selected){HBRUSH brush=CreateSolidBrush(RGB(230,239,255));FillRect(dc,&row,brush);DeleteObject(brush);}row.left+=8;SetTextColor(dc,RGB(25,40,60));DrawTextW(dc,self->candidates[i].c_str(),-1,&row,DT_LEFT|DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS);}SelectObject(dc,previous);DeleteObject(font);EndPaint(window,&ps);return 0;}
        return DefWindowProcW(window,message,w,l);
    }
    void hide(){if(panel)ShowWindow(panel,SW_HIDE);}
    void reset(){raw.clear();cursor=0;selected=0;candidates.clear();release(composition);release(context);hide();}
    HRESULT request(ITfContext* target,std::function<HRESULT(TfEditCookie)>action){if(!target||client==0)return E_FAIL;auto* session=new EditSession(std::move(action));HRESULT edited=E_FAIL;HRESULT hr=target->RequestEditSession(client,session,TF_ES_SYNC|TF_ES_READWRITE,&edited);session->Release();return FAILED(hr)?hr:edited;}
    HRESULT finish(TfEditCookie cookie,const std::wstring& text){
        if(!composition)return S_OK;const std::wstring output=text;ITfRange* range=nullptr;HRESULT hr=composition->GetRange(&range);
        if(SUCCEEDED(hr))hr=range->SetText(cookie,0,output.c_str(),static_cast<LONG>(output.size()));
        if(SUCCEEDED(hr)){range->Collapse(cookie,TF_ANCHOR_END);TF_SELECTION s{range,{TF_AE_NONE,FALSE}};context->SetSelection(cookie,1,&s);ITfComposition* ending=composition;ending->AddRef();ending->EndComposition(cookie);ending->Release();reset();}
        release(range);return hr;
    }
    HRESULT update(TfEditCookie cookie){
        if(!composition||!context)return E_FAIL;ITfRange* range=nullptr;HRESULT hr=composition->GetRange(&range);if(FAILED(hr))return hr;
        hr=range->SetText(cookie,0,raw.c_str(),static_cast<LONG>(raw.size()));
        if(SUCCEEDED(hr)){
            ITfRange* caret=nullptr;range->Clone(&caret);caret->Collapse(cookie,TF_ANCHOR_START);LONG moved=0;caret->ShiftStart(cookie,static_cast<LONG>(cursor),&moved,nullptr);caret->Collapse(cookie,TF_ANCHOR_START);TF_SELECTION s{caret,{TF_AE_NONE,FALSE}};context->SetSelection(cookie,1,&s);
            ITfContextView* view=nullptr;RECT anchor{};BOOL clipped=FALSE;
            if(SUCCEEDED(context->GetActiveView(&view))&&SUCCEEDED(view->GetTextExt(cookie,caret,&anchor,&clipped))){show(anchor);}else hide();release(view);release(caret);
        }
        release(range);return hr;
    }
    void show(RECT anchor){
        if(candidates.empty()||anchor.bottom<=anchor.top){hide();return;}
        if(!panel){WNDCLASSW wc{};wc.lpfnWndProc=windowProc;wc.hInstance=moduleHandle;wc.lpszClassName=L"ShunweiCandidateWindow";wc.hCursor=LoadCursorW(nullptr,IDC_ARROW);RegisterClassW(&wc);panel=CreateWindowExW(WS_EX_TOPMOST|WS_EX_NOACTIVATE|WS_EX_TOOLWINDOW,wc.lpszClassName,L"顺位输入法",WS_POPUP|WS_BORDER,0,0,460,200,nullptr,nullptr,moduleHandle,nullptr);if(panel)SetWindowLongPtrW(panel,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(this));}
        if(!panel)return;MONITORINFO monitor{sizeof(monitor)};GetMonitorInfoW(MonitorFromRect(&anchor,MONITOR_DEFAULTTONEAREST),&monitor);int height=int(candidates.size()*34+12);int x=std::max(int(monitor.rcWork.left),std::min(int(anchor.left),int(monitor.rcWork.right)-460));int y=anchor.bottom+height<=monitor.rcWork.bottom?anchor.bottom:std::max(int(monitor.rcWork.top),int(anchor.top)-height);SetWindowPos(panel,HWND_TOPMOST,x,y,460,height,SWP_NOACTIVATE|SWP_SHOWWINDOW);InvalidateRect(panel,nullptr,TRUE);
    }
    bool disabled(ITfContext* target)const {
        if(secure||!target)return true;
        ITfCompartmentMgr* compartments=nullptr;
        if(FAILED(target->QueryInterface(IID_ITfCompartmentMgr,reinterpret_cast<void**>(&compartments))))return false;
        bool blocked=false;
        for(const GUID* id:{&GUID_COMPARTMENT_KEYBOARD_DISABLED,&GUID_COMPARTMENT_EMPTYCONTEXT}) {
            ITfCompartment* compartment=nullptr;
            if(SUCCEEDED(compartments->GetCompartment(*id,&compartment))) {
                VARIANT value{};
                if(SUCCEEDED(compartment->GetValue(&value))&&value.vt==VT_I4&&value.lVal)blocked=true;
                VariantClear(&value);release(compartment);
            }
        }
        release(compartments);return blocked;
    }
    bool interested(WPARAM key)const{
        if(secure||(GetKeyState(VK_CONTROL)&0x8000)||(GetKeyState(VK_MENU)&0x8000)||(GetKeyState(VK_LWIN)&0x8000)||(GetKeyState(VK_RWIN)&0x8000))return false;
        if(raw.empty())return key>='A'&&key<='Z';
        return (key>='A'&&key<='Z')||(key>='0'&&key<='9')||key==VK_OEM_1||key==VK_OEM_2||key==VK_OEM_3||key==VK_OEM_4||key==VK_OEM_5||key==VK_OEM_6||key==VK_OEM_7||key==VK_OEM_PLUS||key==VK_OEM_MINUS||key==VK_OEM_PERIOD||key==VK_OEM_COMMA||key==VK_BACK||key==VK_DELETE||key==VK_LEFT||key==VK_RIGHT||key==VK_UP||key==VK_DOWN||key==VK_SPACE||key==VK_RETURN||key==VK_ESCAPE;
    }
    HRESULT key(TfEditCookie cookie,WPARAM key,LPARAM flags){
        if(!composition){TF_SELECTION selection{};ULONG fetched=0;HRESULT hr=context->GetSelection(cookie,TF_DEFAULT_SELECTION,1,&selection,&fetched);if(FAILED(hr)||fetched!=1)return E_FAIL;ITfContextComposition* cc=nullptr;hr=context->QueryInterface(IID_ITfContextComposition,reinterpret_cast<void**>(&cc));if(SUCCEEDED(hr))hr=cc->StartComposition(cookie,selection.range,this,&composition);release(cc);release(selection.range);if(FAILED(hr))return hr;}
        if(key==VK_RETURN)return finish(cookie,raw);
        if(key==VK_SPACE)return finish(cookie,candidates.empty()?raw:candidates[selected]);
        if(key==VK_ESCAPE)return finish(cookie,L"");
        if(key==VK_BACK){if(cursor){raw.erase(--cursor,1);}}
        else if(key==VK_DELETE){if(cursor<raw.size())raw.erase(cursor,1);}
        else if(key==VK_LEFT){if(cursor)--cursor;return update(cookie);}
        else if(key==VK_RIGHT){if(cursor<raw.size())++cursor;return update(cookie);}
        else if(key==VK_DOWN||key==VK_UP){if(!candidates.empty())selected=(selected+(key==VK_DOWN?1:candidates.size()-1))%candidates.size();return update(cookie);}
        else {BYTE state[256];GetKeyboardState(state);wchar_t text[8];int n=ToUnicodeEx(UINT(key),UINT((flags>>16)&255),state,text,8,4,GetKeyboardLayout(0));if(n<=0)return S_FALSE;raw.insert(cursor,text,n);cursor+=n;}
        if(raw.empty())return finish(cookie,L"");candidates=engine().decode(raw,true);selected=0;return update(cookie);
    }
public:
    Service(){++objects;}
    ~Service(){Deactivate();if(panel)DestroyWindow(panel);--objects;}
    STDMETHODIMP QueryInterface(REFIID id,void**out)override{if(!out)return E_POINTER;*out=nullptr;if(id==IID_IUnknown||id==IID_ITfTextInputProcessor||id==IID_ITfTextInputProcessorEx)*out=static_cast<ITfTextInputProcessorEx*>(this);else if(id==IID_ITfKeyEventSink)*out=static_cast<ITfKeyEventSink*>(this);else if(id==IID_ITfCompositionSink)*out=static_cast<ITfCompositionSink*>(this);else if(id==IID_ITfThreadMgrEventSink)*out=static_cast<ITfThreadMgrEventSink*>(this);if(!*out)return E_NOINTERFACE;AddRef();return S_OK;}
    STDMETHODIMP_(ULONG) AddRef()override{return ++refs;}
    STDMETHODIMP_(ULONG) Release()override{ULONG n=--refs;if(!n)delete this;return n;}
    STDMETHODIMP Activate(ITfThreadMgr*tm,TfClientId id)override{return ActivateEx(tm,id,0);}
    STDMETHODIMP ActivateEx(ITfThreadMgr*tm,TfClientId id,DWORD flags)override{
        if(!tm)return E_INVALIDARG;if(manager)return E_UNEXPECTED;manager=tm;manager->AddRef();client=id;secure=(flags&TF_TMAE_SECUREMODE)!=0;
        ITfKeystrokeMgr*keys=nullptr;HRESULT hr=manager->QueryInterface(IID_ITfKeystrokeMgr,reinterpret_cast<void**>(&keys));if(SUCCEEDED(hr))hr=keys->AdviseKeyEventSink(client,this,TRUE);release(keys);if(FAILED(hr)){Deactivate();return hr;}
        ITfSource*source=nullptr;hr=manager->QueryInterface(IID_ITfSource,reinterpret_cast<void**>(&source));if(SUCCEEDED(hr))hr=source->AdviseSink(IID_ITfThreadMgrEventSink,static_cast<ITfThreadMgrEventSink*>(this),&sinkCookie);release(source);if(FAILED(hr)){Deactivate();return hr;}return S_OK;
    }
    STDMETHODIMP Deactivate()override{
        if(manager){ITfKeystrokeMgr*keys=nullptr;if(SUCCEEDED(manager->QueryInterface(IID_ITfKeystrokeMgr,reinterpret_cast<void**>(&keys)))){keys->UnadviseKeyEventSink(client);release(keys);}ITfSource*source=nullptr;if(sinkCookie!=TF_INVALID_COOKIE&&SUCCEEDED(manager->QueryInterface(IID_ITfSource,reinterpret_cast<void**>(&source)))){source->UnadviseSink(sinkCookie);release(source);}}
        // A failed write lock leaves the host's raw composition intact, never simulates Backspace.
        if(composition)request(context,[this](TfEditCookie c){return finish(c,raw);});reset();release(manager);client=0;sinkCookie=TF_INVALID_COOKIE;return S_OK;
    }
    STDMETHODIMP OnSetFocus(BOOL foreground)override{if(!foreground){if(composition)request(context,[this](TfEditCookie c){return finish(c,raw);});hide();}return S_OK;}
    STDMETHODIMP OnTestKeyDown(ITfContext*target,WPARAM w,LPARAM,BOOL*eaten)override{if(!eaten)return E_POINTER;*eaten=!disabled(target)&&interested(w);return S_OK;}
    STDMETHODIMP OnTestKeyUp(ITfContext*,WPARAM,LPARAM,BOOL*eaten)override{if(!eaten)return E_POINTER;*eaten=FALSE;return S_OK;}
    STDMETHODIMP OnKeyDown(ITfContext*target,WPARAM w,LPARAM l,BOOL*eaten)override{
        if(!eaten)return E_POINTER;*eaten=FALSE;if(disabled(target)){reset();return S_OK;}if(!interested(w)){if(composition)request(context,[this](TfEditCookie c){return finish(c,raw);});return S_OK;}
        if(context&&context!=target){request(context,[this](TfEditCookie c){return finish(c,raw);});reset();}
        if(!context){context=target;context->AddRef();}
        const auto oldRaw=raw;const auto oldCandidates=candidates;const auto oldCursor=cursor;const auto oldSelected=selected;
        HRESULT hr=request(target,[this,w,l](TfEditCookie c){return key(c,w,l);});
        if(hr!=S_OK){raw=oldRaw;candidates=oldCandidates;cursor=oldCursor;selected=oldSelected;hide();}
        *eaten=hr==S_OK;return S_OK;
    }
    STDMETHODIMP OnKeyUp(ITfContext*,WPARAM,LPARAM,BOOL*eaten)override{if(!eaten)return E_POINTER;*eaten=FALSE;return S_OK;}
    STDMETHODIMP OnPreservedKey(ITfContext*,REFGUID,BOOL*eaten)override{if(!eaten)return E_POINTER;*eaten=FALSE;return S_OK;}
    STDMETHODIMP OnCompositionTerminated(TfEditCookie,ITfComposition*ended)override{if(ended==composition)reset();return S_OK;}
    STDMETHODIMP OnInitDocumentMgr(ITfDocumentMgr*)override{return S_OK;}
    STDMETHODIMP OnUninitDocumentMgr(ITfDocumentMgr*)override{return S_OK;}
    STDMETHODIMP OnSetFocus(ITfDocumentMgr*,ITfDocumentMgr*)override{if(composition)request(context,[this](TfEditCookie c){return finish(c,raw);});hide();return S_OK;}
    STDMETHODIMP OnPushContext(ITfContext*)override{return S_OK;}
    STDMETHODIMP OnPopContext(ITfContext*popped)override{if(popped==context){if(composition)request(context,[this](TfEditCookie c){return finish(c,raw);});reset();}return S_OK;}
};
class Factory:public IClassFactory{
    std::atomic<ULONG> refs{1};
public:
    Factory(){++objects;}~Factory(){--objects;}
    STDMETHODIMP QueryInterface(REFIID id,void**out)override{if(!out)return E_POINTER;*out=nullptr;if(id==IID_IUnknown||id==IID_IClassFactory)*out=static_cast<IClassFactory*>(this);if(!*out)return E_NOINTERFACE;AddRef();return S_OK;}
    STDMETHODIMP_(ULONG) AddRef()override{return ++refs;}
    STDMETHODIMP_(ULONG) Release()override{ULONG n=--refs;if(!n)delete this;return n;}
    STDMETHODIMP CreateInstance(IUnknown*outer,REFIID id,void**out)override{if(outer)return CLASS_E_NOAGGREGATION;auto*service=new Service();HRESULT hr=service->QueryInterface(id,out);service->Release();return hr;}
    STDMETHODIMP LockServer(BOOL lock)override{if(lock)++locks;else --locks;return S_OK;}
};
extern "C" BOOL WINAPI DllMain(HINSTANCE h,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH){moduleHandle=h;DisableThreadLibraryCalls(h);}return TRUE;}
SHUNWEI_COM_EXPORT DllCanUnloadNow(){return objects==0&&locks==0?S_OK:S_FALSE;}
SHUNWEI_COM_EXPORT DllGetClassObject(REFCLSID clsid,REFIID id,void**out){if(clsid!=CLSID_ShUnwei)return CLASS_E_CLASSNOTAVAILABLE;auto*f=new Factory();HRESULT hr=f->QueryInterface(id,out);f->Release();return hr;}
static std::wstring classKey(){wchar_t guid[64];StringFromGUID2(CLSID_ShUnwei,guid,64);return std::wstring(L"CLSID\\")+guid;}
SHUNWEI_COM_EXPORT DllUnregisterServer(){
    HRESULT init=CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);ITfInputProcessorProfiles*profiles=nullptr;ITfCategoryMgr*categories=nullptr;
    HRESULT result=S_OK;if(SUCCEEDED(CoCreateInstance(CLSID_TF_CategoryMgr,nullptr,CLSCTX_INPROC_SERVER,IID_ITfCategoryMgr,reinterpret_cast<void**>(&categories)))){categories->UnregisterCategory(CLSID_ShUnwei,GUID_TFCAT_TIP_KEYBOARD,CLSID_ShUnwei);release(categories);}
    if(SUCCEEDED(CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void**>(&profiles)))){profiles->RemoveLanguageProfile(CLSID_ShUnwei,Language,PROFILE_ShUnwei);result=profiles->Unregister(CLSID_ShUnwei);release(profiles);}
    LSTATUS erased=RegDeleteTreeW(HKEY_CLASSES_ROOT,classKey().c_str());if(erased!=ERROR_SUCCESS&&erased!=ERROR_FILE_NOT_FOUND)result=HRESULT_FROM_WIN32(erased);if(SUCCEEDED(init))CoUninitialize();return result;
}
SHUNWEI_COM_EXPORT DllRegisterServer(){
    HRESULT init=CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);const auto path=modulePath();HKEY key=nullptr;std::wstring registry=classKey()+L"\\InprocServer32";
    LSTATUS status=RegCreateKeyExW(HKEY_CLASSES_ROOT,registry.c_str(),0,nullptr,0,KEY_WRITE,nullptr,&key,nullptr);
    if(status!=ERROR_SUCCESS){if(SUCCEEDED(init))CoUninitialize();return HRESULT_FROM_WIN32(status);}
    status=RegSetValueExW(key,nullptr,0,REG_SZ,reinterpret_cast<const BYTE*>(path.c_str()),DWORD((path.size()+1)*sizeof(wchar_t)));
    const wchar_t model[]=L"Apartment";if(status==ERROR_SUCCESS)status=RegSetValueExW(key,L"ThreadingModel",0,REG_SZ,reinterpret_cast<const BYTE*>(model),sizeof(model));RegCloseKey(key);
    HRESULT hr=status==ERROR_SUCCESS?S_OK:HRESULT_FROM_WIN32(status);ITfInputProcessorProfiles*profiles=nullptr;ITfCategoryMgr*categories=nullptr;
    if(SUCCEEDED(hr))hr=CoCreateInstance(CLSID_TF_InputProcessorProfiles,nullptr,CLSCTX_INPROC_SERVER,IID_ITfInputProcessorProfiles,reinterpret_cast<void**>(&profiles));
    if(SUCCEEDED(hr))hr=profiles->Register(CLSID_ShUnwei);const wchar_t title[]=L"顺位输入法（开发版）";
    if(SUCCEEDED(hr))hr=profiles->AddLanguageProfile(CLSID_ShUnwei,Language,PROFILE_ShUnwei,title,UINT(wcslen(title)),path.c_str(),UINT(path.size()),0);
    if(SUCCEEDED(hr))hr=CoCreateInstance(CLSID_TF_CategoryMgr,nullptr,CLSCTX_INPROC_SERVER,IID_ITfCategoryMgr,reinterpret_cast<void**>(&categories));
    if(SUCCEEDED(hr))hr=categories->RegisterCategory(CLSID_ShUnwei,GUID_TFCAT_TIP_KEYBOARD,CLSID_ShUnwei);
    release(categories);release(profiles);if(SUCCEEDED(init))CoUninitialize();if(FAILED(hr))DllUnregisterServer();return hr;
}
