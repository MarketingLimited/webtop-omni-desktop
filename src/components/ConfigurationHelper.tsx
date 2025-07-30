import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Copy, FileText, Key, Users } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

const ConfigurationHelper = () => {
  const { toast } = useToast();

  const envVars = [
    {
      name: "ADMIN_USERNAME",
      description: "Username for SSH and system administration",
      example: "admin",
      required: true
    },
    {
      name: "ADMIN_PASSWORD", 
      description: "Password for the admin user",
      example: "securepassword123",
      required: true
    },
    {
      name: "TTYD_USER",
      description: "Username for terminal web access",
      example: "terminal",
      required: true
    },
    {
      name: "TTYD_PASSWORD",
      description: "Password for terminal web access", 
      example: "terminalpass123",
      required: true
    }
  ];

  const envTemplate = envVars.map(env => `${env.name}=${env.example}`).join('\n');

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    toast({
      title: "Copied to clipboard",
      description: "Configuration copied successfully",
    });
  };

  return (
    <div className="py-24 px-6 bg-secondary/10">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl font-bold mb-4">Configuration</h2>
          <p className="text-xl text-muted-foreground">
            Set up your environment variables for secure access
          </p>
        </div>
        
        <div className="space-y-8">
          <Card className="bg-gradient-card border-border shadow-card p-6">
            <div className="flex items-center space-x-3 mb-6">
              <FileText className="w-6 h-6 text-primary" />
              <h3 className="text-xl font-semibold">Environment Variables</h3>
            </div>
            
            <div className="space-y-4">
              {envVars.map((env, index) => (
                <div key={index} className="flex flex-col md:flex-row md:items-center justify-between p-4 bg-muted/20 rounded-lg border border-border">
                  <div className="flex-1 space-y-1">
                    <div className="flex items-center space-x-2">
                      <span className="font-mono text-sm font-medium text-foreground">{env.name}</span>
                      {env.required && (
                        <Badge variant="destructive" className="text-xs">Required</Badge>
                      )}
                    </div>
                    <p className="text-sm text-muted-foreground">{env.description}</p>
                    <code className="text-xs text-accent bg-muted/30 px-2 py-1 rounded">
                      Example: {env.example}
                    </code>
                  </div>
                </div>
              ))}
            </div>
          </Card>
          
          <Card className="bg-gradient-card border-border shadow-card p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center space-x-3">
                <Key className="w-6 h-6 text-primary" />
                <h3 className="text-xl font-semibold">.env Template</h3>
              </div>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => copyToClipboard(envTemplate)}
              >
                <Copy className="w-4 h-4 mr-2" />
                Copy
              </Button>
            </div>
            
            <div className="bg-muted/30 rounded-lg p-4 border border-border">
              <pre className="text-sm font-mono text-foreground">
                <code>{envTemplate}</code>
              </pre>
            </div>
            
            <div className="mt-4 p-4 bg-accent/10 border border-accent/30 rounded-lg">
              <div className="flex items-start space-x-2">
                <Users className="w-5 h-5 text-accent mt-0.5" />
                <div className="space-y-1">
                  <p className="text-sm font-medium text-accent">Security Note</p>
                  <p className="text-xs text-muted-foreground">
                    Use strong passwords for production deployments. Consider using Docker secrets 
                    or environment variable files for sensitive data.
                  </p>
                </div>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default ConfigurationHelper;