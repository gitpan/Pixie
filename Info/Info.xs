#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define PIXIE_MAGIC_info (char)0x9b

MAGIC*
_find_mg(SV* sv) {
    MAGIC* mg;
    return mg_find(sv, PIXIE_MAGIC_info);
}

MODULE = Pixie::Info	PACKAGE = Pixie::Info

SV*
px_set_info(ref, info)
    SV* ref
    SV* info
PREINIT:
    SV* sv;
    MAGIC* mg;
    MGVTBL *vtable = 0;
CODE:
    if (!SvROK(ref)) {
        croak("px_get_info needs a reference!");
    }

    sv  = (SV*) SvRV(ref);

    mg = _find_mg(sv);
    if (mg) {
        // delete the old value
        SvREFCNT_dec(mg->mg_obj);
        SvREFCNT_inc(info);
        mg->mg_obj = info;
    } else {
        sv_magicext(sv, info, PIXIE_MAGIC_info, vtable, NULL, 0);
        SvRMAGICAL_on(sv);
    }
OUTPUT:
    ref

SV*
px_get_info(ref)
    SV* ref
PREINIT:
    MAGIC* mg;
    SV* sv;
CODE:
    if (!SvROK(ref)) {
        croak("px_get_info needs a reference!");
    }

    sv = (SV*) SvRV(ref);
    mg = _find_mg(sv);
    if (mg) {
	RETVAL = newSVsv(mg->mg_obj);
    }
    else {
        RETVAL = &PL_sv_undef;
    }
OUTPUT:
    RETVAL

