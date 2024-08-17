---Source:
---https://github.com/google-gemini/cookbook/blob/main/quickstarts/rest/Streaming_REST.ipynb

local log = require("codecompanion.utils.log")
local utils = require("codecompanion.utils.adapters")

---@class CodeCompanion.AdapterArgs
return {
  name = "gemini",
  roles = {
    llm = "model",
    user = "user",
  },
  features = {
    tokens = true,
    text = true,
    vision = true,
  },
  url = "https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse&key=${api_key}",
  env = {
    api_key = "GEMINI_API_KEY",
    model = "schema.model.default",
  },
  headers = {
    ["Content-Type"] = "application/json",
  },
  callbacks = {
    ---Set the parameters
    ---@param params table
    ---@param messages table
    ---@return table
    form_parameters = function(params, messages)
      return params
    end,

    ---Set the format of the role and content for the messages from the chat buffer
    ---@param self CodeCompanion.Adapter
    ---@param messages table Format is: { contents = { parts { text = "Your prompt here" } }
    ---@return table
    form_messages = function(self, messages)
      -- Format system prompts
      local system = utils.pluck_messages(vim.deepcopy(messages), "system")
      for _, msg in ipairs(system) do
        msg.text = msg.content
        msg.tag = nil
        msg.content = nil
        msg.role = nil
      end
      local sys_prompts = {
        role = self.args.roles.user,
        parts = system,
      }

      -- Format messages (remove all system prompts
      local output = {}
      local user = utils.pop_messages(messages, "system")
      for _, msg in ipairs(user) do
        table.insert(output, {
          role = self.args.roles.user,
          parts = {
            { text = msg.content },
          },
        })
      end

      return {
        system_instruction = sys_prompts,
        contents = output,
      }
    end,

    ---Has the streaming completed?
    ---@param data string The data from the format_data callback
    ---@return boolean
    is_complete = function(data)
      -- log:trace("Data: %s", stuff)
    end,

    ---Returns the number of tokens generated from the LLM
    ---@param data string The data from the LLM
    ---@return number|nil
    tokens = function(data) end,

    ---Output the data from the API ready for insertion into the chat buffer
    ---@param data string The streamed JSON data from the API, also formatted by the format_data callback
    ---@return table|nil
    chat_output = function(data)
      local output = {}

      if data and data ~= "" then
        data = data:sub(6)
        local ok, json = pcall(vim.json.decode, data, { luanil = { object = true } })

        if ok then
          output.role = "llm"
          output.content = json.candidates[1].content.parts[1].text

          return {
            status = "success",
            output = output,
          }
        end
      end
    end,

    ---Output the data from the API ready for inlining into the current buffer
    ---@param data table The streamed JSON data from the API, also formatted by the format_data callback
    ---@param context table Useful context about the buffer to inline to
    ---@return table|nil
    inline_output = function(data, context)
      if data and data ~= "" then
        data = data:sub(6)
        local ok, json = pcall(vim.json.decode, data, { luanil = { object = true } })

        if not ok then
          return
        end

        return json.candidates[1].content.parts[1].text
      end
    end,

    ---Callback to catch any errors from the standard output
    ---@param data table
    ---@return nil
    on_stdout = function(data)
      local stdout = table.concat(data._stdout_results)

      local ok, json = pcall(vim.json.decode, stdout, { luanil = { object = true } })
      log:trace("stdout: %s", json)
      if ok then
        if json.error then
          log:error("Error: %s", json.error.message)
        end
      end
    end,
  },
  schema = {
    model = {
      order = 1,
      type = "enum",
      desc = "The model that will complete your prompt. See https://ai.google.dev/gemini-api/docs/models/gemini#model-variations for additional details and options.",
      default = "gemini-1.5-flash",
      choices = {
        "gemini-1.5-flash",
        "gemini-1.5-pro",
        "gemini-1.0-pro",
      },
    },
  },
}