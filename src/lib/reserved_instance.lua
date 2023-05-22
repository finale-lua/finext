local reserved_instance = {}

function reserved_instance.ExtClassName(class)
  return class.ClassName
end

function reserved_instance.ExtParent(class)
  return class.Parent
end

function reserved_instance.ExtBase(class)
  return classes.Base
end

return reserved_instance
