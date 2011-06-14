CPANM        := cpanm -q
CPAN_MIRROR  := --mirror http://cpan.sgn.cornell.edu/CPAN/ --mirror-only
#CPAN_MIRROR  := --mirror /data/shared/cpan-mirror/cpan --mirror-only
LL_NAME      := $(PWD)/extlib
DPAN         := $(PWD)/dpan

STARMACHINE_DEPS := Server::Starter Starman Net::Server::SS::PreFork
DPAN_BLACKLIST   := JSON::PP common::sense HTML::Parser

all: $(LL_NAME)

$(LL_NAME): 
	mkdir -p $(DPAN);
	# install the blacklisted modules from the upstream mirror without trying to use the dpan
	$(CPANM)                      -L $(LL_NAME) $(CPAN_MIRROR) $(DPAN_BLACKLIST);
	# try first to installdeps from our DPAN as much as possible
	-$(CPANM)                     -L $(LL_NAME) --mirror $(DPAN) --mirror-only --installdeps .;
	-$(CPANM)                     -L $(LL_NAME) --mirror $(DPAN) --mirror-only $(STARMACHINE_DEPS);
	# then try to installdeps from the upstream mirror, saving stuff in the dpan
	$(CPANM) --save-dists $(DPAN) -L $(LL_NAME) $(CPAN_MIRROR) --installdeps .;
	$(CPANM) --save-dists $(DPAN) -L $(LL_NAME) $(CPAN_MIRROR) $(STARMACHINE_DEPS);
	# and update the dpan indexes for our next run
	cd $(DPAN) && dpan

clean:
	rm -rf $(LL_NAME);

.PHONY: $(LL_NAME)
