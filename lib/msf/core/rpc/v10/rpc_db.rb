module Msf
module RPC
class RPC_Db < RPC_Base

private
	def db 
		self.framework.db.active
	end

	def find_workspace(wspace = nil)
	 	if(wspace and wspace != "")
			return self.framework.db.find_workspace(wspace) 
		end
		self.framework.db.workspace
	end

	def fix_options(opts)
		newopts = {}
		opts.each do |k,v|
			newopts[k.to_sym] = v
		end
		newopts
	end

	def opts_to_hosts(opts)
		wspace = find_workspace(opts[:workspace]) 
		hosts  = []
		if opts[:host] or opts[:address]
			host = opts[:host] || opts[:address]
			hent = wspace.hosts.find_by_address(host)
			return hosts if hent == nil
			hosts << hent if hent.class == Msf::DBManager::Host
			hosts |= hent if hent.class == Array
		elsif opts[:addresses]
			return hosts if opts[:addresses].class != Array
			conditions = {}
			conditions[:address] = opts[:addresses]
			hent = wspace.hosts.where(conditions)
			hosts |= hent if hent.class == Array
		end
		return hosts
	end

	def opts_to_services(hosts,opts)
		wspace = find_workspace(opts[:workspace]) 
		services = []
		if opts[:host] or opts[:address] or opts[:addresses]
			return services if hosts.count < 1
			hosts.each do |h|
				if opts[:port] or opts[:proto]
					conditions = {}
					conditions[:port] = opts[:port] if opts[:port]
					conditions[:proto] = opts[:proto] if opts[:proto]
					sret = h.services.where(conditions)
					next if sret == nil
					services |= sret if sret.class == Array
					services << sret if sret.class == Msf::DBManager::Service
				else
					services |= h.services
				end
			end
		elsif opts[:port] or opts[:proto]
			conditions = {}
			conditions[:port] = opts[:port] if opts[:port]
			conditions[:proto] = opts[:proto] if opts[:proto]
			sret = wspace.services.where(conditions)
			services |= sret if sret.class == Array
			services << sret if sret.class == Msf::DBManager::Service
		end
		return services
	end
	
	def db_check
		error(500, "Database Not Loaded") if not db
	end

public

	def rpc_hosts(xopts)

		db_check

		opts = fix_options(xopts)

		conditions = {}
		conditions[:state] = [Msf::HostState::Alive, Msf::HostState::Unknown] if opts[:only_up]
		conditions[:address] = opts[:addresses] if opts[:addresses]

		wspace = find_workspace(opts[:workspace])

		ret = {}
		ret[:hosts] = []
		wspace.hosts.where(conditions).order(:address).each do |h|
			host = {}
			host[:created_at] = h.created_at.to_i
			host[:address] = h.address.to_s
			host[:address6] = h.address6.to_s
			host[:mac] = h.mac.to_s
			host[:name] = h.name.to_s
			host[:state] = h.state.to_s
			host[:os_name] = h.os_name.to_s
			host[:os_flavor] = h.os_flavor.to_s
			host[:os_sp] = h.os_sp.to_s
			host[:os_lang] = h.os_lang.to_s
			host[:updated_at] = h.updated_at.to_i
			host[:purpose] = h.purpose.to_s
			host[:info] = h.info.to_s
			ret[:hosts]  << host
		end
		ret
	end

	def rpc_services( xopts)

		db_check

		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace])
		opts[:workspace] = wspace if opts[:workspace]
		hosts = []

		if opts[:addresses]
			conditions = {}
			conditions[:address] = opts[:addresses] if opts[:addresses]
			hosts = wspace.hosts.where(conditions).order.(:address)
		elsif opts[:host] || opts[:address]
			host = self.framework.db.get_host(opts)
			hosts << host
		end

		ret = {}
		ret[:services] = []

		a = self.framework.db.get_host(opts)

		services = []
		if opts[:host] || opts[:address] || opts[:addresses]
			hosts.each do |host|
				sret = nil
				if(opts[:proto] && opts[:port])
					sret = host.services.find_by_proto_and_port(opts[:proto], opts[:port])
				else
					sret = host.services
				end
				next if sret == nil
				services << sret if sret.class == Msf::DBManager::Service
				services |= sret if sret.class == Array
			end
		else
			services = wspace.services
		end

		return ret if (not services)
		
		services.each do |s|
			service = {}
			host = s.host
			service[:host] = host.address || host.address6 || "unknown"
			service[:created_at] = s[:created_at].to_i
			service[:updated_at] = s[:updated_at].to_i
			service[:port] = s[:port]
			service[:proto] = s[:proto].to_s
			service[:state] = s[:state].to_s
			service[:name] = s[:name].to_s
			service[:info] = s[:info].to_s
			ret[:services] << service
		end
		ret
	end


	def rpc_vulns(xopts)
		
		db_check
		
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace])
		opts[:workspace] = wspace if opts[:workspace]

		ret = {}
		ret[:vulns] = []
		hosts = []
		services = []
		vulns = []
		# Get Matching Hosts
		if opts[:addresses]
			conditions = {}
			conditions[:address] = opts[:addresses] if opts[:addresses]
			hosts = wspace.hosts.where(conditions).order(:address)
		elsif opts[:host] || opts[:address]
			host = self.framework.db.get_host(opts)
			hosts << host
		end

		#Get Matching Services
		if opts[:host] || opts[:address] || opts[:addresses]
			hosts.each do |host|
				sret = nil
				if(opts[:proto] && opts[:port])
					sret = host.services.find_by_proto_and_port(opts[:proto], opts[:port])
				else
					sret = host.services
				end
				next if sret == nil
				services << sret if sret.class == Msf::DBManager::Service
				services |= sret if sret.class == Array
			end
		elsif opts[:port] && opts[:proto]
			sret = wspace.services.find_by_proto_and_port(opts[:proto],opts[:port])
			services << sret if sret.class == Msf::DBManager::Service
			services |= sret if sret.class == Array
		end
		
		#get list of vulns
		if services.count > 0
			services.each do |s|
				if opts[:name]
					nret = s.vulns.find_by_name(opts[:name])
				else
					nret = s.vulns
				end
				next if nret == nil
				vulns << nret if nret.class == Msf::DBManager::Vuln
				vulns |= nret if nret.class == Array
			end
		elsif hosts.count > 0
			hosts.each do |h|
				if opts[:name]
					nret = h.vulns.find_by_name(opts[:name])
				else
					nret = h.vulns
				end
				next if nret == nil
				vulns << nret if nret.class == Msf::DBManager::Vuln
				vulns |= nret if nret.class == Array
			end
		else
			nret = wspace.vulns
			vulns << nret if nret.class == Msf::DBManager::Vuln
			vulns |= nret if nret.class == Array
		end

		vulns.each do |v|
			vuln = {}
			reflist = v.refs.map { |r| r.name }
			if(v.service)	
				vuln[:port] = v.service.port
				vuln[:proto] = v.service.proto
			else
				vuln[:port] = nil
				vuln[:proto] = nil
			end
			vuln[:time] = v.created_at.to_i
			vuln[:host] = v.host.address || v.host.address6 || nil	
			vuln[:name] = v.name
			vuln[:refs] = reflist.join(',')
			ret[:vulns] << vuln
		end
		ret
	end

	def rpc_workspaces
		db_check

		res = {}
		res[:workspaces] = []
		self.framework.db.workspaces.each do |j|
			ws = {}
			ws[:name] = j.name
			ws[:created_at] = j.created_at.to_i
			ws[:updated_at] = j.updated_at.to_i
			res[:workspaces] << ws
		end
		res
	end

	def rpc_current_workspace
		db_check
		{ "workspace" => self.framework.db.workspace.name }
	end

	def rpc_get_workspace(wspace)
		db_check
		wspace = find_workspace(wspace)
		ret = {}
		ret[:workspace] = []
		if(wspace)
			w = {}
			w[:name] = wspace.name
			w[:created_at] = wspace.created_at.to_i
			w[:modified_at] = wspace.modified_at.to_i
			ret[:workspace] << w
		end
		ret
	end

	def rpc_set_workspace(wspace)
		db_check
		workspace = self.framework.db.find_workspace(wspace)
		if(workspace)
			self.framework.db.workspace = workspace
			return { 'result' => "success" }
		end
		{ 'result' => 'failed' }
	end

	def rpc_del_workspace(wspace)
		db_check
		# Delete workspace
		workspace = self.framework.db.find_workspace(wspace)
		if workspace.nil?
			error(404, "Workspace not found: #{wspace}")
		elsif workspace.default?
			workspace.destroy
			workspace = self.framework.db.add_workspace(workspace.name)
		else
			# switch to the default workspace if we're about to delete the current one
			self.framework.db.workspace = self.framework.db.default_workspace if self.framework.db.workspace.name == workspace.name
			# now destroy the named workspace
			workspace.destroy
		end
		{ 'result' => "success" }
	end

	def rpc_add_workspace(wspace)
		db_check
		wspace = self.framework.db.add_workspace(wspace)
		return { 'result' => 'success' } if(wspace)
		{ 'result' => 'failed' }
	end

	def rpc_get_host(xopts)
		db_check
		
		ret = {}
		ret[:host] = []
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		h = self.framework.db.get_host(opts)
		if(h)
			host = {}
			host[:created_at] = h.created_at.to_i
			host[:address] = h.address.to_s
			host[:address6] = h.address6.to_s
			host[:mac] = h.mac.to_s
			host[:name] = h.name.to_s
			host[:state] = h.state.to_s
			host[:os_name] = h.os_name.to_s
			host[:os_flavor] = h.os_flavor.to_s
			host[:os_sp] = h.os_sp.to_s
			host[:os_lang] = h.os_lang.to_s
			host[:updated_at] = h.updated_at.to_i
			host[:purpose] = h.purpose.to_s
			host[:info] = h.info.to_s
			ret[:host] << host
		end
		ret	
	end

	def rpc_report_host(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]

		res = self.framework.db.report_host(opts)
		return { :result => 'success' } if(res)
		{ :result => 'failed' }
		
	end

	def rpc_report_service(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		res = self.framework.db.report_service(opts)
		return { :result => 'success' } if(res)
		{ :result => 'failed' }
	end

	def rpc_get_service(xopts)
		db_check
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace])
		opts[:workspace] = wspace if opts[:workspace]

		ret = {}
		ret[:service] = []

		host = self.framework.db.get_host(opts)

		services = []
		sret = nil

		if(host && opts[:proto] && opts[:port])
			sret = host.services.find_by_proto_and_port(opts[:proto], opts[:port])
		elsif(opts[:proto] && opts[:port])
			conditions = {}
			conditions[:state] = [ServiceState::Open] if opts[:up]
			conditions[:proto] = opts[:proto] if opts[:proto]
			conditions[:port] = opts[:port] if opts[:port]
			conditions[:name] = opts[:names] if opts[:names]
			sret = wspace.services.where(conditions).order("hosts.address, port")
		else
			sret = host.services
		end
		return ret if sret == nil
		services << sret if sret.class == Msf::DBManager::Service
		services |= sret if sret.class == Array

		
		services.each do |s|
			service = {}
			host = s.host
			service[:host] = host.address || host.address6 || "unknown"
			service[:created_at] = s[:created_at].to_i
			service[:updated_at] = s[:updated_at].to_i
			service[:port] = s[:port]
			service[:proto] = s[:proto].to_s
			service[:state] = s[:state].to_s
			service[:name] = s[:name].to_s
			service[:info] = s[:info].to_s
			ret[:service] << service
		end
		ret
	end

	def rpc_get_note(xopts)
		db_check
		
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]

		ret = {}
		ret[:note] = []

		host = self.framework.db.get_host(opts)

		return ret if( not host)
		notes = []
		if(opts[:proto] && opts[:port])
			services = []
			nret = host.services.find_by_proto_and_port(opts[:proto], opts[:port])
			return ret if nret == nil
			services << nret if nret.class == Msf::DBManager::Service
			services |= nret if nret.class == Array

			services.each do |s|
				nret = nil
				if opts[:ntype]
					nret = s.notes.find_by_ntype(opts[:ntype])
				else
					nret = s.notes
				end
				next if nret == nil
				notes << nret if nret.class == Msf::DBManager::Note
				notes |= nret if nret.class == Array
			end
		else
			notes = host.notes
		end
		notes.each do |n|
			note = {}
			host = n.host
			note[:host] = host.address || host.address6 || "unknown"
			if n.service
				note[:port] = n.service.port
				note[:proto] = n.service.proto
			end
			note[:created_at] = n[:created_at].to_i
			note[:updated_at] = n[:updated_at].to_i
			note[:ntype] = n[:ntype].to_s
			note[:data] = n[:data]
			note[:critical] = n[:critical].to_s
			note[:seen] = n[:seen].to_s
			ret[:note] << note
		end
		ret
	end

	def rpc_get_client(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		ret = {}
		ret[:client] = []
		c = self.framework.db.get_client(opts)
		if(c)
			client = {}
			host = c.host
			client[:host] = host.address
			client[:created_at] = c.created_at.to_i
			client[:updated_at] = c.updated_at.to_i
			client[:ua_string] = c.ua_string.to_s
			client[:ua_name] = c.ua_name.to_s
			client[:ua_ver] = c.ua_ver.to_s
			ret[:client] << client
		end
		ret
	end

	def rpc_report_client(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		res = self.framework.db.report_client(opts)
		return { :result => 'success' } if(res)
		{ :result => 'failed' }
	end

	#DOC NOTE: :data and :ntype are REQUIRED
	def rpc_report_note(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		if (opts[:host] or opts[:address]) and opts[:port] and opts[:proto]
			addr = opts[:host] || opts[:address]
			wspace = opts[:workspace] || self.framework.db.workspace
			host = wspace.hosts.find_by_address(addr)
			service = host.services.find_by_proto_and_port(opts[:proto],opts[:port]) if host.services.count > 0
			opts[:service] = service if service
		end
			
		res = self.framework.db.report_note(opts)
		return { :result => 'success' } if(res)
		{ :result => 'failed' }
	end

	def rpc_notes(xopts)
		db_check
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace]) if opts[:workspace]
		opts[:workspace] = wspace

		ret = {}
		ret[:notes] = []
		hosts = []
		services = []
		notes = []

		# Get Matching Hosts
		if opts[:addresses]
			conditions = {}
			conditions[:address] = opts[:addresses] if opts[:addresses]
			hosts = wspace.hosts.where(conditions).order(:address)
		elsif opts[:host] || opts[:address]
			host = self.framework.db.get_host(opts)
			hosts << host
		end

		#Get Matching Services
		if opts[:host] || opts[:address] || opts[:addresses]
			hosts.each do |host|
				sret = nil
				if(opts[:proto] && opts[:port])
					sret = host.services.find_by_proto_and_port(opts[:proto], opts[:port])
				else
					sret = host.services
				end
				next if sret == nil
				services << sret if sret.class == Msf::DBManager::Service
				services |= sret if sret.class == Array
			end
		elsif opts[:port] && opts[:proto]
			sret = wspace.services.find_by_proto_and_port(opts[:proto],opts[:port])
			services << sret if sret.class == Msf::DBManager::Service
			services |= sret if sret.class == Array
		end
		
		#get list of notes
		if services.count > 0
			services.each do |s|
				if opts[:ntype]
					nret = s.notes.find_by_ntype(opts[:ntype])
				else
					nret = s.notes
				end
				next if nret == nil
				notes << nret if nret.class == Msf::DBManager::Note
				notes |= nret if nret.class == Array
			end
		elsif hosts.count > 0
			hosts.each do |h|
				if opts[:ntype]
					nret = h.notes.find_by_ntype(opts[:ntype])
				else
					nret = h.notes
				end
				next if nret == nil
				notes << nret if nret.class == Msf::DBManager::Note
				notes |= nret if nret.class == Array
			end
		else
			nret = wspace.notes
			notes << nret if nret.class == Msf::DBManager::Note
			notes |= nret if nret.class == Array
		end

		notes.each do |n|
			note = {}
			note[:time] = n.created_at.to_i
			note[:host] = ""
			note[:service] = ""
			note[:host] = n.host.address || n.host.address6 if(n.host)
			note[:service] = n.service.name || n.service.port  if(n.service)
			note[:type ] = n.ntype.to_s
			note[:data] = n.data.inspect
			ret[:notes] << note
		end
		ret
	end

	def rpc_report_auth_info(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		res = self.framework.db.report_auth_info(opts)
		return { :result => 'success' } if(res)
		{ :result => 'failed' }
	end

	def rpc_get_auth_info(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		ret = {}
		ret[:auth_info] = []
		ai = self.framework.db.get_auth_info(opts)
		ai.each do |i|
			info = {}
			i.each do |k,v|
				info[k.to_sym] = v
			end
			ret[:auth_info] << info	
		end
		ret
	end

	def rpc_get_ref(name)
		db_check
		self.framework.db.get_ref(name)
	end

	def rpc_del_vuln(xopts)
		db_check
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace]) 
		hosts  = []
		services = []
		vulns = []
			
		if opts[:host] or opts[:address] or opts[:addresses]
			hosts = opts_to_hosts(opts)
		end

		if opts[:port] or opts[:proto]
			if opts[:host] or opts[:address] or opts[:addresses]
				services = opts_to_services(hosts,opts)
			else
				services = opts_to_services([],opts)
			end
		end

		if opts[:port] or opts[:proto]
			services.each do |s|
				vret = nil
				if opts[:name]
					vret = s.vulns.find_by_name(opts[:name])
				else
					vret = s.vulns
				end
				next if vret == nil
				vulns << vret if vret.class == Msf::DBManager::Vuln
				vulns |= vret if vret.class == Array
			end
		elsif opts[:address] or opts[:host] or opts[:addresses]
			hosts.each do |h|
				vret = nil
				if opts[:name]
					vret = h.vulns.find_by_name(opts[:name])
				else
					vret = h.vulns
				end
				next if vret == nil
				vulns << vret if vret.class == Msf::DBManager::Vuln
				vulns |= vret if vret.class == Array
			end
		else
			vret = nil
			if opts[:name]
				vret = wspace.vulns.find_by_name(opts[:name])
			else
				vret = wspace.vulns
			end
			vulns << vret if vret.class == Msf::DBManager::Vuln
			vulns |= vret if vret.class == Array
		end

		deleted = []
		vulns.each do |v|
			dent = {}
			dent[:address] = v.host.address.to_s if v.host
			dent[:port] = v.service.port if v.service
			dent[:proto] = v.service.proto if v.service
			dent[:name] = v.name
			deleted << dent
			v.destroy	
		end
			
		return { :result => 'success', :deleted => deleted } 
	end

	def rpc_del_note(xopts)
		db_check
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace]) 
		hosts  = []
		services = []
		notes = []
			
		if opts[:host] or opts[:address] or opts[:addresses]
			hosts = opts_to_hosts(opts)
		end

		if opts[:port] or opts[:proto]
			if opts[:host] or opts[:address] or opts[:addresses]
				services = opts_to_services(hosts,opts)
			else
				services = opts_to_services([],opts)
			end
		end

		if opts[:port] or opts[:proto]
			services.each do |s|
				nret = nil
				if opts[:ntype]
					nret = s.notes.find_by_ntype(opts[:ntype])
				else
					nret = s.notes
				end
				next if nret == nil
				notes << nret if nret.class == Msf::DBManager::Note
				notes |= nret if nret.class == Array
			end
		elsif opts[:address] or opts[:host] or opts[:addresses]
			hosts.each do |h|
				nret = nil
				if opts[:ntype]
					nret = h.notes.find_by_ntype(opts[:ntype])
				else
					nret = h.notes
				end
				next if nret == nil
				notes << nret if nret.class == Msf::DBManager::Note
				notes |= nret if nret.class == Array
			end
		else
			nret = nil
			if opts[:ntype]
				nret = wspace.notes.find_by_ntype(opts[:ntype])
			else
				nret = wspace.notes
			end
			notes << nret if nret.class == Msf::DBManager::Note
			notes |= nret if nret.class == Array
		end
		deleted = []
		notes.each do |n|
			dent = {}
			dent[:address] = n.host.address.to_s if n.host
			dent[:port] = n.service.port if n.service
			dent[:proto] = n.service.proto if n.service
			dent[:ntype] = n.ntype
			deleted << dent
			n.destroy	
		end
			
		return { :result => 'success', :deleted => deleted } 
	end

	def rpc_del_service(xopts)
		db_check
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace]) 
		hosts  = []
		services = []
		if opts[:host] or opts[:address]
			host = opts[:host] || opts[:address]
			hent = wspace.hosts.find_by_address(host)
			return { :result => 'failed' } if hent == nil or hent.class != Msf::DBManager::Host
			hosts << hent
		elsif opts[:addresses]
			return { :result => 'failed' } if opts[:addresses].class != Array
			conditions = { :address => opts[:addresses] }
			hent = wspace.hosts.where(conditions)
			return { :result => 'failed' } if hent == nil
			hosts |= hent if hent.class == Array
			hosts << hent if hent.class == Msf::DBManager::Host
		end
		if opts[:addresses] or opts[:address] or opts[:host]
			hosts.each do |h|
				sret = nil
				if opts[:port] or opts[:proto]
					conditions = {}
					conditions[:port] = opts[:port] if opts[:port]
					conditions[:proto] = opts[:proto] if opts[:proto]
					sret = h.services.where(conditions)
					next if sret == nil
					services << sret if sret.class == Msf::DBManager::Service
					services |= sret if sret.class == Array
				else
					services |= h.services
				end
			end
		elsif opts[:port] or opts[:proto]
			conditions = {}
			conditions[:port] = opts[:port] if opts[:port]
			conditions[:proto] = opts[:proto] if opts[:proto]
			sret = wspace.services.where(conditions)
			services << sret if sret and sret.class == Msf::DBManager::Service
			services |= sret if sret and sret.class == Array
		end
		
		deleted = []
		services.each do |s|
			dent = {}
			dent[:address] = s.host.address.to_s
			dent[:port] = s.port
			dent[:proto] = s.proto
			deleted << dent
			s.destroy	
		end
			
		return { :result => 'success', :deleted => deleted } 
	end

	def rpc_del_host(xopts)
		db_check
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace]) 
		hosts  = []
		if opts[:host] or opts[:address]
			host = opts[:host] || opts[:address]
			hent = wspace.hosts.find_by_address(host)
			return { :result => 'failed' } if hent == nil or hent.class != Msf::DBManager::Host
			hosts << hent
		elsif opts[:addresses]
			return { :result => 'failed' } if opts[:addresses].class != Array
			conditions = { :address => opts[:addresses] }
			hent = wspace.hosts.where(conditions)
			return { :result => 'failed' } if hent == nil
			hosts |= hent if hent.class == Array
			hosts << hent if hent.class == Msf::DBManager::Host
		end
		deleted = []
		hosts.each do |h|
			deleted << h.address.to_s
			h.destroy	
		end
			
		return { :result => 'success', :deleted => deleted } 
	end


	def rpc_report_vuln(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		res = self.framework.db.report_vuln(opts)
		return { :result => 'success' } if(res)
		{ :result => 'failed' }
	end


	def rpc_events(wspace = nil)
		db_check
		wspace = find_workspace(wspace)
		error(500, "Unknown Workspace") if(not wspace)
		ret = {}
		ret[:events] = []

		self.framework.db.events(wspace).each do |e|
			event = {}
			event[:host] = e.host.address || e.host.address6 if(e.host)
			event[:created_at] = e.created_at.to_i
			event[:updated_at] = e.updated_at.to_i
			event[:name] = e.name
			event[:critical] = e.critical if(e.critical)	
			event[:username] = e.username if(e.username)	
			event[:info] = e.info
			ret[:events] << event
		end
		ret
	end
	
	def rpc_report_event(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		res = self.framework.db.report_event(opts)
		{ :result => 'success' } if(res)
	end

	#NOTE Path is required
	#NOTE To match a service need host, port, proto
	def rpc_report_loot(xopts)
		db_check
		opts = fix_options(xopts)
		if opts[:host] && opts[:port] && opts[:proto]
			opts[:service] = self.framework.db.find_or_create_service(opts)
		end

		res = self.framework.db.report_loot(opts)
		{ :result => 'success' } if(res)
	end

	def rpc_loots(wspace=nil)
		db_check
		wspace = find_workspace(wspace)
		error(500, "Unknown Workspace") if(not wspace)
		
		ret = {}
		ret[:loots] = []
		self.framework.db.loots(wspace).each do |l|
			loot = {}
			loot[:host] = l.host.address || l.host.address6 if(l.host)
			loot[:service] = l.service.name || n.service.port  if(n.service)
			loot[:ltype] = l.ltype
			loot[:ctype] = l.ctype
			loot[:data] = l.data
			loot[:created_at] = l.created_at.to_i
			loot[:updated_at] = l.updated_at.to_i
			loot[:name] = l.name
			loot[:info] = l.info
			ret[:loots] << loot
		end
		ret
	end

	# requires host, port, user, pass, ptype, and active
	def rpc_report_cred(xopts)
		db_check
		opts = fix_options(xopts)
		res = framework.db.find_or_create_cred(opts)
		return { :result => 'success' } if res
		{ :result => 'failed' }
	end
	
	#right now workspace is the only option supported
	def rpc_creds(xopts)
		db_check
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace])
		ret = {}
		ret[:creds] = []
		self.framework.db.creds(wspace).each do |c|
			cred = {}
			cred[:host] = c.service.host.address || c.service.host.address6 if(c.service.host)
			cred[:time] = c.updated_at
			cred[:port] = c.service.port
			cred[:proto] = c.service.proto
			cred[:sname] = c.service.name
			cred[:type] = c.ptype
			cred[:user] = c.user
			cred[:pass] = c.pass
			cred[:active] = c.active
			ret[:creds] << cred
		end
		ret
	end
	
	def rpc_import_data(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]
		self.framework.db.import(opts)
		return { :result => 'success' }
	end

	def rpc_get_vuln(xopts)
		db_check
		opts = fix_options(xopts)
		opts[:workspace] = find_workspace(opts[:workspace]) if opts[:workspace]

		ret = {}
		ret[:vuln] = []

		host = self.framework.db.get_host(opts)

		return ret if( not host)
		vulns = []

		if(opts[:proto] && opts[:port])
			services = []
			sret = host.services.find_by_proto_and_port(opts[:proto], opts[:port])
			return ret if sret == nil
			services << sret if sret.class == Msf::DBManager::Service
			services |= sret if sret.class == Array
			
			services.each do |s|
				vulns |= s.vulns
			end
		else
			vulns = host.vulns
		end

		return ret if (not vulns)
		
		vulns.each do |v|
			vuln= {}
			host= v.host
			vuln[:host] = host.address || host.address6 || "unknown"
			if v.service
				vuln[:port] = v.service.port
				vuln[:proto] = v.service.proto
			end
			vuln[:created_at] = v[:created_at].to_i
			vuln[:updated_at] = v[:updated_at].to_i
			vuln[:name] = v[:name].to_s
			vuln[:info] = v[:info].to_s
			vuln[:refs] = []
			v.refs.each do |r|
				vuln[:refs] << r.name
			end	
			ret[:vuln] << vuln
		end
		ret
	end
	
	def rpc_clients(xopts)
		db_check
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace]) 
		hosts = []
		clients = []
		ret = {}
		ret[:clients] = []

		if opts[:host] or opts[:address] or opts[:addresses]
			hosts = opts_to_hosts(opts)
		else
			hosts = wspace.hosts
		end

		hosts.each do |h|
			cret = nil
			if opts[:ua_name] or opts[:ua_ver]	
				conditions = {}
				conditions[:ua_name] = opts[:ua_name] if opts[:ua_name]
				conditions[:ua_ver] = opts[:ua_ver] if opts[:ua_ver]
				cret = h.clients.where(conditions)
			else
				cret = h.clients
			end
			next if cret == nil
			clients << cret if cret.class == Msf::DBManager::Client
			clients |= cret if cret.class == Array
		end
		clients.each do |c|
			client = {}
			client[:host] = c.host.address.to_s if c.host
			client[:ua_string] = c.ua_string
			client[:ua_name] = c.ua_name
			client[:ua_ver] = c.ua_ver
			client[:created_at] = c.created_at.to_i
			client[:updated_at] = c.updated_at.to_i
			ret[:clients] << client
		end
		ret
	end

	def rpc_del_client(xopts)
		db_check
		opts = fix_options(xopts)
		wspace = find_workspace(opts[:workspace]) 
		hosts = []
		clients = []

		if opts[:host] or opts[:address] or opts[:addresses]
			hosts = opts_to_hosts(opts)
		else
			hosts = wspace.hosts
		end

		hosts.each do |h|
			cret = nil
			if opts[:ua_name] or opts[:ua_ver]	
				conditions = {}
				conditions[:ua_name] = opts[:ua_name] if opts[:ua_name]
				conditions[:ua_ver] = opts[:ua_ver] if opts[:ua_ver]
				cret = h.clients.where(conditions)
			else
				cret = h.clients
			end
			next if cret == nil
			clients << cret if cret.class == Msf::DBManager::Client
			clients |= cret if cret.class == Array
		end

		deleted = []
		clients.each do |c|
			dent = {}
			dent[:address] = c.host.address.to_s
			dent[:ua_string] = c.ua_string
			deleted << dent
			c.destroy	
		end

		{ :result => 'success', :deleted => deleted } 	
	end

	def rpc_driver(xopts)
		opts = fix_options(xopts)
		if opts[:driver]
			if self.framework.db.drivers.include?(opts[:driver])
				self.framework.db.driver = opts[:driver]
				return { :result => 'success' }
			else
				return { :result => 'failed' }

			end
		else
			return { :driver => self.framework.db.driver.to_s }
		end
		return { :result => 'failed' }
	end

	def rpc_connect(xopts)
		opts = fix_options(xopts)
		if(not self.framework.db.driver and not opts[:driver])
			return { :result => 'failed' }
		end

		if opts[:driver]
			if self.framework.db.drivers.include?(opts[:driver])
				self.framework.db.driver = opts[:driver]
			else
				return { :result => 'failed' }
			end
		end
		
		driver = self.framework.db.driver

		case driver
		when 'postgresql'
			opts['adapter'] = 'postgresql'
		else
			return { :result => 'failed' }
		end
	
		if (not self.framework.db.connect(opts))		
			return { :result => 'failed' }
		end
		return { :result => 'success' }
		
	end

	def rpc_status
		if (not self.framework.db.driver)
			return {:driver => 'None' }
		end
		
		cdb = ""
		if ActiveRecord::Base.connected? and ActiveRecord::Base.connection.active?
			if ActiveRecord::Base.connection.respond_to? :current_database
				cdb = ActiveRecord::Base.connection.current_database
			else
				cdb = ActiveRecord::Base.connection.instance_variable_get(:@config)[:database]
			end
			return {:driver => self.framework.db.driver.to_s , :db => cdb }
		else
			return {:driver => self.framework.db.driver.to_s}
		end
		{:driver => 'None' }
	end
	
	def rpc_disconnect
		if (self.framework.db)
			self.framework.db.disconnect()
			return { :result => 'success' }
		else
			return { :result => 'failed' }
		end
	end


end
end
end
