import hudson.model.*;
import jenkins.model.*;

Thread.start {
      sleep 10000
      def env = System.getenv()
      println "--> setting agent port for jnlp"
      Jenkins.instance.setSlaveAgentPort(env['JENKINS_SLAVE_AGENT_PORT'].toInteger())
      println "--> setting agent port for jnlp... done"
}
