-- Mixin code
function Mixin(object, ...)
	local mixins = {...}
	for _,mixin in pairs(mixins) do
		for k,v in next, mixin do
			object[k] = v
		end
	end
	return object
end

function CreateFromMixins(...)
	return Mixin({ }, ...)
end

function CreateAndInitFromMixin(mixin, ...)
	local object = CreateFromMixins(mixin);
	object:Init(...);
	return object;
end