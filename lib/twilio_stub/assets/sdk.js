window.Twilio = {
  host: "#HOST#",
  token: '',
  Chat: {
    Client: {
      create: function(token) {
        const client = this;
        window.Twilio.token = token;

        return new Promise(function(resolve) {
          setTimeout(function() {
            resolve(client);
          }, 500);
        });
      },
      getSubscribedChannels: function() {
        return new Promise(function(resolve) {
          setTimeout(function() {
            resolve();
          }, 500);
        });
      },
      getChannelByUniqueName: function(name) {
        return new Promise(function(resolve) {
          window.Twilio.Channel.name = name;

          const host = window.Twilio.host;
          const token = window.Twilio.token;
          const url = `${host}/js_api/channels/${name}?token=${token}`

          fetch(url).then(function() { resolve(window.Twilio.Channel) })
       });
      }
    }
  },
  Channel: {
    name: null,
    socket: null,
    lastMessageId: null,
    messageHandlerInterval: null,
    messageHandler: null,
    handleMessagePool: function(body) {
      const channel = window.Twilio.Channel;

      if (body.message && body.message.sid !== channel.lastMessageId) {
        channel.lastMessageId = body.message.sid;
        if (body.message.mediaUrl) {
          body.message.media = {};

          body.message.media.getContentUrl = function() {
            const promise = new Promise(function(resolve) {
              resolve(body.message.mediaUrl);
            })

            return promise;
          };
        }

        window.
          Twilio.
          Channel.
          messageHandler(body.message);
      }
    },
    join: function() {
      const channel = this;
      return new Promise(function(resolve) {
        const interval = setInterval(
          function () {
            const host = window.Twilio.host;
            const name = window.Twilio.Channel.name;

            fetch(`${host}/js_api/channels/${name}/messages`).
              then(function(response) { return response.json() }).
              then(channel.handleMessagePool)
          },
          400
        );
        this.messageHandlerInterval = interval;

        resolve(this);
      });
    },
    on: function(_, callback) {
      this.messageHandler = callback;
    },
    sendMessage: function(message) {
      const host = window.Twilio.host;
      const name = window.Twilio.Channel.name;

      fetch(`${host}/js_api/channels/${name}/messages`, {
        method: "POST",
        body: JSON.stringify({ message: message }),
      }).then(function() { console.log('Message send!') });
    },
  },
};

